# imports
if module?
  global._ = require('lodash')
  global.utils = require('./utils.coffee')
  global.errors = require('./errors.coffee')
  global.constants = require('./constants.coffee')
  global.Logger = require('./logger.coffee')
  global.EventEmitter = require('./eventEmitter.coffee')

class Row
  constructor: (@parent, @id) ->

  getParent: () ->
    @parent

  # NOTE: in the future, this may contain other info
  serialize: () ->
    return @id

  setParent: (parent) ->
    @parent = parent

  debug: () ->
    (do @getAncestry).join ", "

  isRoot: () ->
    @id == constants.root_id

  clone: () ->
    new Row (@parent?.clone?()), @id

  # gets a list of IDs
  getAncestry: () ->
    if do @isRoot then return []
    ancestors = do @parent.getAncestry
    ancestors.push @id
    ancestors

  # Represents the exact same row
  is: (other) ->
    if @id != other.id then return false
    if do @isRoot then return do other.isRoot
    if do other.isRoot then return false
    return (do @getParent).is (do other.getParent)

Row.getRoot = () ->
  new Row null, constants.root_id

Row.loadFrom = (parent, serialized) ->
  id = if typeof serialized == 'number'
    serialized
  else
    serialized.id
  new Row parent, id

Row.loadFromAncestry = (ancestry) ->
  if ancestry.length == 0
    return do Row.getRoot
  id = do ancestry.pop
  parent = Row.loadFromAncestry ancestry
  new Row parent, id

###
Data is a wrapper class around the actual datastore, providing methods to manipulate the data
the data itself includes:
  - the location that is currently being viewed
  - the text in each line, including text properties like bold/italic
  - the parent/child relationships and collapsed-ness of lines
also deals with loading the initial data from the datastore, and serializing the data to a string

Currently, the separation between the View and Data classes is not very good.  (see view.coffee)
###
class Data extends EventEmitter
  root: do Row.getRoot

  constructor: (store) ->
    super
    @store = store
    @viewRoot = Row.loadFromAncestry (do @store.getLastViewRoot || [])
    return @

  changeViewRoot: (row) ->
    @viewRoot = row
    @store.setLastViewRoot do row.getAncestry

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
    return (@store.getLine row.id).map (obj) ->
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
    return (@store.setLine row.id, (line.map (obj) ->
      # if no properties are true, serialize just the character to save space
      if _.all constants.text_properties.map ((property) => (not obj[property]))
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
    return text[start..end].join('')

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

  _getChildren: (id) ->
    return @store.getChildren id

  _setChildren: (id, children) ->
    return @store.setChildren id, children

  _getParents: (id) ->
    return @store.getParents id

  _setParents: (id, children_id) ->
    @store.setParents id, children_id

  getChildren: (parent) ->
    (Row.loadFrom parent, serialized) for serialized in @_getChildren parent.id

  setChildren: (parent, children) ->
    for child in children
      errors.assert (child.parent == parent)
    @_setChildren parent.id, (do child.serialize for child in children)

  findChild: (row, id) ->
    _.find (@getChildren row), (x) -> x.id == id

  hasChildren: (row) ->
    return ((@getChildren row).length > 0)

  getSiblings: (row) ->
    return @getChildren (do row.getParent)

  indexOf: (child) ->
    children = @getSiblings child
    return _.findIndex children, (sib) ->
        sib.id == child.id

  collapsed: (row) ->
    return @store.getCollapsed row.id

  toggleCollapsed: (row) ->
    @store.setCollapsed row.id, (not @collapsed row)

  # a node is cloned only if it has multiple parents.
  # note that this may return false even if it appears multiple times in the display (if its ancestor is cloned)
  # The intent is to see whether adding/removing a node will add/remove the corresponding id when maintaining metadata.
  isClone: (id) ->
    parents = @_getParents id
    if parents.length < 2 # for efficiency reasons
      return false
    numAttachedParents = (parents.filter (parent) => @isAttached parent).length
    return numAttachedParents > 1

  # Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
  canonicalInstance: (id) -> # Given an id, return a row with that id
    errors.assert id?, "Empty id passed to canonicalInstance"
    if id == constants.root_id
      return @root
    parentId = (@_getParents id)[0] # This is the only actual choice made
    errors.assert parentId?, "No parent found for id: #{id}"
    canonicalParent = @canonicalInstance parentId
    instance = @findChild canonicalParent, id
    errors.assert instance?, "No canonical instance found for id: #{id}"
    return instance

  # Return all ancestor ids, topologically sorted (root is *last*).
  # Excludes 'id' itself unless options.inclusive is specified
  allAncestors: (id, options) ->
    options = _.defaults {}, options, { inclusive: false }
    visited = {}
    ancestors = [] # 'visited' with preserved insert order
    if options.inclusive
      ancestors.push id
    visit = (n) => # DFS
      visited[n] = true
      for parent in @_getParents n
        if parent not of visited
          ancestors.push parent
          visit parent
    visit id
    ancestors

  # Return what would be all the ancestors of 'id', if 'excluded_parent_id'
  # were removed as a parent of 'id'.
  # Excludes 'id' itself unless options.inclusive is specified
  allAncestorsWithoutParent: (id, excluded_parent_id, options) ->
    options = _.defaults {}, options, { inclusive: false }
    ancestors = []
    if options.inclusive
      ancestors.push id
    for parent_id in _.without (@_getParents id), excluded_parent_id
      ancestors = _.union ancestors, (@allAncestors parent_id, { inclusive: true })
    ancestors

  # whether currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable: (row) ->
    return (not @collapsed row) or (row.is @viewRoot)

  # detach a block from the graph
  detach: (row) ->
    parent = do row.getParent
    index = @indexOf row
    @_detach row.id, parent.id
    return {
      parent: parent
      index: index
    }

  _hasChild: (parent_id, id) ->
    children = @_getChildren parent_id
    ci = _.findIndex children, (sib) -> (sib == id)
    return ci != -1

  _removeChild: (parent_id, id) ->
    children = @_getChildren parent_id
    ci = _.findIndex children, (sib) -> (sib == id)
    errors.assert (ci != -1)
    children.splice ci, 1
    @_setChildren parent_id, children

    parents = @_getParents id
    pi = _.findIndex parents, (par) -> (par == parent_id)
    parents.splice pi, 1
    @_setParents id, parents

    info = {
      parentId: parent_id,
      parentIndex: pi,
      childId: id,
      childIndex: ci,
    }
    @emit "childRemoved", info
    return info

  _addChild: (parent_id, id, index) ->
    children = @_getChildren parent_id
    errors.assert (index <= children.length)
    if index == -1
      children.push id
    else
      children.splice index, 0, id
    @_setChildren parent_id, children

    parents = @_getParents id
    parents.push parent_id
    @_setParents id, parents
    info = {
      parentId: parent_id,
      parentIndex: parents.length - 1,
      childId: id,
      childIndex: index,
    }
    @emit "childAdded", info
    return info

  _detach: (id, parent_id) ->
    original_ancestry = @allAncestors id, { inclusive: true }
    new_ancestry = @allAncestorsWithoutParent id, parent_id, { inclusive: true }
    removed_ancestry = _.difference original_ancestry, new_ancestry
    wasLast = (@_getParents id).length == 1

    # Notify all ancestors that their list of descendants changed
    for ancestorId in removed_ancestry
      @emit "beforeDescendantRemoved", { ancestorId: ancestorId, descendantId: id }
    if wasLast
      @emit "beforeRowRemoved", { id: id, parent_id: parent_id }

    info = @_removeChild parent_id, id

    # Notify all ancestors that their list of descendants changed
    for ancestorId in removed_ancestry
      @emit "afterDescendantRemoved", { ancestorId: ancestorId, descendantId: id }
    if wasLast
      @emit "afterRowRemoved", { id: id, parent_id: parent_id }
    return info

  _attach: (child_id, parent_id, index = -1) ->
    original_ancestry = @allAncestors child_id, { inclusive: true }
    new_ancestry = _.union (@allAncestors child_id, { inclusive: true }), (@allAncestors parent_id, { inclusive: true })
    added_ancestry = _.difference new_ancestry, original_ancestry
    isFirst = (@_getParents child_id).length == 0

    # Notify all ancestors thaat their list of descendants changed
    for ancestorId in added_ancestry
      @emit "beforeDescendantAdded", { ancestorId: ancestorId, descendantId: child_id }
    if isFirst
      @emit "beforeRowAdded", { id: child_id, parent_id: parent_id }

    info = @_addChild parent_id, child_id, index

    # Notify all ancestors thaat their list of descendants changed
    for ancestorId in added_ancestry
      @emit "afterDescendantAdded", { ancestorId: ancestorId, descendantId: child_id }
    if isFirst
      @emit "afterRowAdded", { id: child_id, parent_id: parent_id }
    return info

  _move: (child_id, old_parent_id, new_parent_id, index = -1) ->
    original_ancestry = @allAncestors child_id, { inclusive: true }
    new_ancestry = _.union (@allAncestorsWithoutParent child_id, old_parent_id, { inclusive: true }), (@allAncestors new_parent_id, { inclusive: true })
    added_ancestry = _.difference new_ancestry, original_ancestry
    removed_ancestry = _.difference original_ancestry, new_ancestry

    # Notify all ancestors thaat their list of descendants changed
    for ancestorId in added_ancestry
      @emit "beforeDescendantAdded", { ancestorId: ancestorId, descendantId: child_id }
    for ancestorId in removed_ancestry
      @emit "beforeDescendantRemoved", { ancestorId: ancestorId, descendantId: child_id }

    remove_info = @_removeChild old_parent_id, child_id

    if (old_parent_id == new_parent_id) and (index > remove_info.childIndex)
      index = index - 1
    add_info = @_addChild new_parent_id, child_id, index

    # Notify all ancestors thaat their list of descendants changed
    for ancestorId in added_ancestry
      @emit "afterDescendantAdded", { ancestorId: ancestorId, descendantId: child_id }
    for ancestorId in removed_ancestry
      @emit "afterDescendantRemoved", { ancestorId: ancestorId, descendantId: child_id }
    return {
      old: remove_info
      new: add_info
    }

  # attaches a detached child to a parent
  # the child should not have a parent already
  attachChild: (parent, child, index = -1) ->
    (@attachChildren parent, [child], index)[0]

  attachChildren: (parent, new_children, index = -1) ->
    @_attachChildren parent.id, (x.id for x in new_children), index
    for child in new_children
      child.setParent parent
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
      row = do row.getParent
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

  # extends a row's path by a path of ids going downwards (used when moving blocks around)
  combineAncestry: (row, id_path) ->
    for id in id_path
      row = @findChild row, id
      unless row?
        return null
    return row

  nextVisible: (row = @viewRoot) ->
    if @viewable row
      children = @getChildren row
      if children.length > 0
        return children[0]
    while true
      nextsib = @getSiblingAfter row
      if nextsib?
        return nextsib
      row = do row.getParent
      if row.is @viewRoot
        return null

  # last thing visible nested within id
  lastVisible: (row = @viewRoot) ->
    if not @viewable row
      return row
    children = @getChildren row
    if children.length > 0
      return @lastVisible children[children.length - 1]
    return row

  prevVisible: (row) ->
    prevsib = @getSiblingBefore row
    if prevsib?
      return @lastVisible prevsib
    parent = do row.getParent
    if parent.is @viewRoot
      return null
    return parent

  # finds oldest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  oldestVisibleAncestor: (row) ->
    last = row
    while true
      cur = do last.getParent
      if cur.is @viewRoot
        return last
      if do cur.isRoot
        return null
      last = cur

  # finds closest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  youngestVisibleAncestor: (row) ->
    answer = row
    cur = row
    while true
      cur = do cur.getParent
      if cur.is @viewRoot
        return answer
      if do cur.isRoot
        return null
      if @collapsed cur
        answer = cur

  # returns whether an id is actually reachable from the root node
  # if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached: (id) ->
    return (@root.id in @allAncestors id, {inclusive: true})

  getSiblingBefore: (row) ->
    return @getSiblingOffset row, -1

  getSiblingAfter: (row) ->
    return @getSiblingOffset row, 1

  getSiblingOffset: (row, offset) ->
    return (@getSiblingRange row, offset, offset)[0]

  getSiblingRange: (row, min_offset, max_offset) ->
    children = @getSiblings row
    index = @indexOf row
    return @getChildRange (do row.getParent), (min_offset + index), (max_offset + index)

  getChildRange: (row, min, max) ->
    children = @getChildren row
    indices = [min..max]

    return indices.map (index) ->
      if index >= children.length
        return null
      else if index < 0
        return null
      else
        return children[index]

  addChild: (row, index = -1) ->
    id = do @store.getNew
    child = new Row row, id
    @attachChild row, child, index

  _insertSiblingHelper: (row, after) ->
    if row.id == @viewRoot.id
      Logger.logger.error 'Cannot insert sibling of view root'
      return null

    parent = do row.getParent
    index = @indexOf row

    return (@addChild parent, (index + after))

  insertSiblingAfter: (row) ->
    return @_insertSiblingHelper row, 1

  insertSiblingBefore: (row) ->
    return @_insertSiblingHelper row, 0

  orderedLines: () ->
    # TODO: deal with clones
    rows = []

    helper = (row) =>
      rows.push row
      for child in @getChildren row
        helper child
    helper @root
    return rows

  #################
  # serialization #
  #################

  # important: serialized automatically garbage collects
  serialize: (row = @root, options={}, serialized={}) ->
    line = @getLine row
    text = (@getText row).join('')

    if row.id of serialized
      struct = serialized[row.id]
      struct.id = row.id
      return { clone: row.id }

    struct = {
      text: text
    }
    children = (@serialize childrow, options, serialized for childrow in @getChildren row)
    if children.length
      struct.children = children

    for property in constants.text_properties
      if _.any (line.map ((obj) -> obj[property]))
        struct[property] = ((if obj[property] then '.' else ' ') for obj in line).join ''

    if (do row.isRoot) and not (do @viewRoot.isRoot)
      struct.viewRoot = @viewRoot

    if @collapsed row
      struct.collapsed = true

    struct = @applyHook 'serializeRow', struct, {row: row}
    serialized[row.id] = struct

    if options.pretty
      if children.length == 0 and (not @isClone row.id) and \
          (_.all Object.keys(struct), (key) ->
            return key in ['children', 'text', 'collapsed'])
        return text
    return struct

  loadTo: (serialized, parent = @root, index = -1, id_mapping = {}) ->
    if serialized.clone
      # NOTE: this assumes we load in the same order we serialize
      errors.assert (serialized.clone of id_mapping)
      id = id_mapping[serialized.clone]
    else
      id = do @store.getNew

    row = new Row parent, id

    if not (do row.isRoot)
      @attachChild parent, row, index
    else
      row.setParent null
      @_setParents row.id, [@root.id]

    if serialized.clone
      return row

    if typeof serialized == 'string'
      @setLine row, (serialized.split '')
    else
      if serialized.id
        id_mapping[serialized.id] = row.id
      line = (serialized.text.split '').map((char) -> {char: char})
      for property in constants.text_properties
        if serialized[property]
          for i, val of serialized[property]
            if val == '.'
              line[i][property] = true

      @setLine row, line
      @store.setCollapsed row.id, serialized.collapsed

      if serialized.children
        for serialized_child in serialized.children
          @loadTo serialized_child, row, -1, id_mapping

    @emit 'loadRow', row, serialized

    return row

  load: (serialized) ->
    if serialized.viewRoot
      @viewRoot = Row.loadFromAncestry serialized.viewRoot
    else
      @viewRoot = @root

    @loadTo serialized

# exports
module?.exports = Data
window?.Data = Data
# hacky, used only for rendering...
window?.Row = Row
