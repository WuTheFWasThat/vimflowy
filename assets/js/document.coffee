_ = require 'lodash'
utils = require './utils.coffee'
errors = require './errors.coffee'
constants = require './constants.coffee'
Logger = require './logger.coffee'
EventEmitter = require './eventEmitter.coffee'

# represents a tree-traversal starting from the root going down
# should be immutable
class Path
  constructor: (@parent, @row) ->

  isRoot: () ->
    @row == constants.root_row

  # gets a list of IDs
  getAncestry: () ->
    if do @isRoot then return []
    ancestors = do @parent.getAncestry
    ancestors.push @row
    ancestors

  child: (row) ->
    new Path @, row

  isDescendant: (other_path) ->
    return (@walkFrom other_path) != null

  walkFrom: (ancestor) ->
    my_ancestry = do @getAncestry
    their_ancestry = do ancestor.getAncestry
    if my_ancestry.length < their_ancestry.length
      return null
    for i in [0...their_ancestry.length]
      if my_ancestry[i] != their_ancestry[i]
        return null
    return my_ancestry.slice their_ancestry.length

  shedUntil: (row) ->
    ancestor = @
    path = []
    while ancestor.row != row
      if !ancestor.parent
        return [null, null]
      path.push ancestor.row
      ancestor = ancestor.parent
    return [path.reverse(), ancestor]

  extend: (walk) ->
    descendent = @
    for row in walk
      descendent = descendent.child row
    return descendent

  # Represents the exact same row
  is: (other) ->
    if @row != other.row then return false
    if do @isRoot then return do other.isRoot
    if do other.isRoot then return false
    return @parent.is other.parent

Path.getRoot = () ->
  new Path null, constants.root_row

Path.loadFromAncestry = (ancestry) ->
  if ancestry.length == 0
    return do Path.getRoot
  row = do ancestry.pop
  parent = Path.loadFromAncestry ancestry
  parent.child row

###
Document is a wrapper class around the actual datastore, providing methods to manipulate the document
the document itself includes:
  - the text in each line, including text properties like bold/italic
  - the parent/child relationships and collapsed-ness of lines
also deals with loading the initial document from the datastore, and serializing the document to a string

Currently, the separation between the Session and Document classes is not very good.  (see session.coffee)
###
class Document extends EventEmitter
  root: do Path.getRoot

  constructor: (store) ->
    super
    @store = store
    return @

  #########
  # lines #
  #########

  # an array of objects:
  # {
  #   char: 'a'
  #   bold: true
  #   italic: false
  # }
  # in the case where all properties are false, it may be simply the character (to save space)
  getLine: (row) ->
    return (@store.getLine row).map (obj) ->
      if typeof obj == 'string'
        obj = {
          char: obj
        }
      return obj

  getText: (row, col) ->
    return @getLine(row).map ((obj) -> obj.char)

  getChar: (row, col) ->
    return @getLine(row)[col]?.char

  setLine: (row, line) ->
    return (@store.setLine row, (line.map (obj) ->
      # if no properties are true, serialize just the character to save space
      if _.every constants.text_properties.map ((property) -> (not obj[property]))
        return obj.char
      else
        return obj
    ))

  # get word at this location
  # if on a whitespace character, return nothing
  getWord: (row, col) ->
    text = @getText row

    if utils.isWhitespace text[col]
      return ''

    start = col
    end = col
    while (start > 0) and not (utils.isWhitespace text[start-1])
      start -= 1
    while (end < text.length - 1) and not (utils.isWhitespace text[end+1])
      end += 1
    word = text[start..end].join('')
    # remove leading and trailing punctuation
    word = word.replace /^[-.,()&$#!\[\]{}"']+/g, ""
    word = word.replace /[-.,()&$#!\[\]{}"']+$/g, ""
    word

  writeChars: (row, col, chars) ->
    args = [col, 0].concat chars
    line = @getLine row
    [].splice.apply line, args
    @setLine row, line

  deleteChars: (row, col, num) ->
    line = @getLine row
    deleted = line.splice col, num
    @setLine row, line
    return deleted

  getLength: (row) ->
    return @getLine(row).length

  #############
  # structure #
  #############

  _getChildren: (row) ->
    return @store.getChildren row

  _setChildren: (row, children) ->
    return @store.setChildren row, children

  _getChildRange: (row, min, max) ->
    children = @_getChildren row
    indices = [min..max]
    return indices.map (index) ->
      if index >= children.length
        return null
      else if index < 0
        return null
      else
        return children[index]

  _getParents: (row) ->
    return @store.getParents row

  _setParents: (row, children_rows) ->
    @store.setParents row, children_rows

  getChildren: (parent_path) ->
    (parent_path.child row) for row in @_getChildren parent_path.row

  findChild: (parent_path, row) ->
    _.find (@getChildren parent_path), (x) -> x.row == row

  hasChildren: (row) ->
    return ((@_getChildren row).length > 0)

  getSiblings: (row) ->
    return @getChildren row.parent

  nextClone: (path) ->
    parents = @_getParents path.row
    i = parents.indexOf path.parent.row
    errors.assert i > -1
    while true
      i = (i + 1) % parents.length
      new_parent = parents[i]
      new_parent_path = @canonicalPath new_parent
      # this happens if the parent got detached
      if new_parent_path != null
        break
    return new_parent_path.child path.row

  indexOf: (child) ->
    children = @getSiblings child
    return _.findIndex children, (sib) ->
      sib.row == child.row

  collapsed: (row) ->
    return @store.getCollapsed row

  toggleCollapsed: (row) ->
    @store.setCollapsed row, (not @collapsed row)

  # last thing visible nested within row
  walkToLastVisible: (row, pathsofar=[]) ->
    if @collapsed row
      return pathsofar
    children = @_getChildren row
    if children.length == 0
      return pathsofar
    child = children[children.length - 1]
    return [child].concat @walkToLastVisible child

  # a node is cloned only if it has multiple parents.
  # note that this may return false even if it appears multiple times in the display (if its ancestor is cloned)
  isClone: (row) ->
    parents = @_getParents row
    if parents.length < 2 # for efficiency reasons
      return false
    numAttachedParents = (parents.filter (parent) => @isAttached parent).length
    return numAttachedParents > 1

  # Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
  # NOTE: this is not very efficient, in the worst case, but probably doesn't matter
  canonicalPath: (row) -> # Given an row, return a path with that row
    errors.assert row?, "Empty row passed to canonicalPath"
    if row == constants.root_row
      return @root
    for parentRow in @_getParents row
      canonicalParent = @canonicalPath parentRow
      if canonicalParent != null
        return @findChild canonicalParent, row
    return null

  # Return all ancestor rows, topologically sorted (root is *last*).
  # Excludes 'row' itself unless options.inclusive is specified
  # NOTE: includes possibly detached nodes
  allAncestors: (row, options) ->
    options = _.defaults {}, options, { inclusive: false }
    visited = {}
    ancestors = [] # 'visited' with preserved insert order
    if options.inclusive
      ancestors.push row
    visit = (n) => # DFS
      visited[n] = true
      for parent in @_getParents n
        if parent not of visited
          ancestors.push parent
          visit parent
    visit row
    ancestors

  # detach a block from the graph
  detach: (path) ->
    parent = path.parent
    index = @indexOf path
    @_detach path.row, parent.row
    return {
      parent: parent
      index: index
    }

  _hasChild: (parent_row, row) ->
    children = @_getChildren parent_row
    ci = _.findIndex children, (sib) -> (sib == row)
    return ci != -1

  _removeChild: (parent_row, row) ->
    children = @_getChildren parent_row
    ci = _.findIndex children, (sib) -> (sib == row)
    errors.assert (ci != -1)
    children.splice ci, 1
    @_setChildren parent_row, children

    parents = @_getParents row
    pi = _.findIndex parents, (par) -> (par == parent_row)
    parents.splice pi, 1
    @_setParents row, parents

    info = {
      parentId: parent_row,
      parentIndex: pi,
      childId: row,
      childIndex: ci,
    }
    @emit "childRemoved", info
    return info

  _addChild: (parent_row, row, index) ->
    children = @_getChildren parent_row
    errors.assert (index <= children.length)
    if index == -1
      children.push row
    else
      children.splice index, 0, row
    @_setChildren parent_row, children

    parents = @_getParents row
    parents.push parent_row
    @_setParents row, parents
    info = {
      parentId: parent_row,
      parentIndex: parents.length - 1,
      childId: row,
      childIndex: index,
    }
    @emit "childAdded", info
    return info

  _detach: (row, parent_row) ->
    wasLast = (@_getParents row).length == 1

    @emit "beforeDetach", { id: row, parent_id: parent_row, last: wasLast }
    info = @_removeChild parent_row, row
    if wasLast
      @store.setDetachedParent row, parent_row
      detached_children = @store.getDetachedChildren parent_row
      detached_children.push row
      @store.setDetachedChildren parent_row, detached_children
    @emit "afterDetach", { id: row, parent_id: parent_row, last: wasLast }
    return info

  _attach: (child_row, parent_row, index = -1) ->
    isFirst = (@_getParents child_row).length == 0
    @emit "beforeAttach", { id: child_row, parent_id: parent_row, first: isFirst}
    info = @_addChild parent_row, child_row, index
    old_detached_parent = @store.getDetachedParent child_row
    if old_detached_parent != null
      errors.assert isFirst
      @store.setDetachedParent child_row, null
      detached_children = @store.getDetachedChildren old_detached_parent
      ci = _.findIndex detached_children, (sib) -> (sib == child_row)
      errors.assert (ci != -1)
      detached_children.splice ci, 1
      @store.setDetachedChildren old_detached_parent, detached_children
    @emit "afterAttach", { id: child_row, parent_id: parent_row, first: isFirst, old_detached_parent: old_detached_parent}
    return info

  _move: (child_row, old_parent_row, new_parent_row, index = -1) ->
    @emit "beforeMove", { id: child_row, old_parent: old_parent_row, new_parent: new_parent_row }

    remove_info = @_removeChild old_parent_row, child_row
    if (old_parent_row == new_parent_row) and (index > remove_info.childIndex)
      index = index - 1
    add_info = @_addChild new_parent_row, child_row, index

    @emit "afterMove", { id: child_row, old_parent: old_parent_row, new_parent: new_parent_row }

    return {
      old: remove_info
      new: add_info
    }

  # attaches a detached child to a parent
  # the child should not have a parent already
  attachChild: (parent, child, index = -1) ->
    (@attachChildren parent, [child], index)[0]

  attachChildren: (parent, new_children, index = -1) ->
    @_attachChildren parent.row, (x.row for x in new_children), index
    # for child in new_children
    #   child.setParent parent
    return new_children

  _attachChildren: (parent, new_children, index = -1) ->
    for child in new_children
      @_attach child, parent, index
      if index >= 0
        index += 1

  # returns an array representing the ancestry of a row,
  # up until the ancestor specified by the `stop` parameter
  # i.e. [stop, stop's child, ... , row's parent , row]
  getAncestry: (row, stop = @root) ->
    ancestors = []
    until row.is stop
      errors.assert (not do row.isRoot), "Failed to get ancestry for #{row} going up until #{stop}"
      ancestors.push row
      row = row.parent
    ancestors.push stop
    do ancestors.reverse
    return ancestors

  # given two rows, returns
  # 1. the common ancestor of the rows
  # 2. the array of ancestors between common ancestor and row1
  # 3. the array of ancestors between common ancestor and row2
  getCommonAncestor: (row1, row2) ->
    ancestors1 = @getAncestry row1
    ancestors2 = @getAncestry row2
    commonAncestry = _.takeWhile (_.zip ancestors1, ancestors2), (pair) ->
      pair[0]? and pair[1]? and pair[0].is pair[1]
    common = (_.last commonAncestry)[0]
    firstDifference = commonAncestry.length
    return [common, ancestors1[firstDifference..], ancestors2[firstDifference..]]

  # extends a path by a list of rows going downwards (used when moving blocks around)
  combineAncestry: (path, row_path) ->
    for row in row_path
      path = @findChild path, row
      unless path?
        return null
    return path

  # returns whether an row is actually reachable from the root node
  # if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached: (row) ->
    return (@root.row in @allAncestors row, {inclusive: true})

  getSiblingBefore: (path) ->
    return @getSiblingOffset path, -1

  getSiblingAfter: (path) ->
    return @getSiblingOffset path, 1

  getSiblingOffset: (path, offset) ->
    return (@getSiblingRange path, offset, offset)[0]

  getSiblingRange: (path, min_offset, max_offset) ->
    children = @getSiblings path
    index = @indexOf path
    return @getChildRange path.parent, (min_offset + index), (max_offset + index)

  getChildRange: (path, min, max) ->
    (@_getChildRange path.row, min, max).map ((child_row) ->
      if child_row == null
        return null
      return path.child child_row
    )

  _newChild: (parent, index = -1) ->
    row = do @store.getNew
    @_attach row, parent, index
    return row

  addChild: (path, index = -1) ->
    row = @_newChild path.row, index
    return (path.child row)

  orderedLines: () ->
    # TODO: deal with clones
    paths = []

    helper = (path) =>
      paths.push path
      for child in @getChildren path
        helper child
    helper @root
    return paths

  #################
  # serialization #
  #################

  # important: serialized automatically garbage collects
  serializeRow: (row = @root.row) ->
    line = @getLine row
    text = (@getText row).join('')
    struct = {
      text: text
    }

    for property in constants.text_properties
      if _.some (line.map ((obj) -> obj[property]))
        struct[property] = ((if obj[property] then '.' else ' ') for obj in line).join ''
    if @collapsed row
      struct.collapsed = true

    struct = @applyHook 'serializeRow', struct, {row: row}
    return struct

  serialize: (row = @root.row, options={}, serialized={}) ->
    if row of serialized
      struct = serialized[row]
      struct.id = row
      return { clone: row }

    struct = @serializeRow row
    children = (@serialize childrow, options, serialized for childrow in @_getChildren row)
    if children.length
      struct.children = children

    serialized[row] = struct

    if options.pretty
      if children.length == 0 and (not @isClone row) and \
          (_.every Object.keys(struct), (key) ->
            return key in ['children', 'text', 'collapsed'])
        return struct.text
    return struct

  loadTo: (serialized, parent_path = @root, index = -1, id_mapping = {}, replace_empty = false) ->
    if serialized.clone
      # NOTE: this assumes we load in the same order we serialize
      errors.assert (serialized.clone of id_mapping)
      row = id_mapping[serialized.clone]
      path = parent_path.child row
      @attachChild parent_path, path, index
      return path

    children = @getChildren parent_path
    # if parent_path has only one child and it's empty, delete it
    if replace_empty and children.length == 1 and ((@getLine children[0].row).length == 0)
      path = children[0]
    else
      path = @addChild parent_path, index

    if typeof serialized == 'string'
      @setLine path.row, (serialized.split '')
    else
      if serialized.id
        id_mapping[serialized.id] = path.row
      line = (serialized.text.split '').map((char) -> {char: char})
      for property in constants.text_properties
        if serialized[property]
          for i, val of serialized[property]
            if val == '.'
              line[i][property] = true

      @setLine path.row, line
      @store.setCollapsed path.row, serialized.collapsed

      if serialized.children
        for serialized_child in serialized.children
          @loadTo serialized_child, path, -1, id_mapping

    @emit 'loadRow', path, serialized

    return path

  load: (serialized_rows) ->
    id_mapping = {}
    for serialized_row in serialized_rows
      @loadTo serialized_row, @root, -1, id_mapping, true

# exports
exports.Path = Path
exports.Document = Document
