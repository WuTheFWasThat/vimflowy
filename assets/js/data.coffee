# imports
if module?
  global._ = require('lodash')
  global.utils = require('./utils.coffee')
  global.errors = require('./errors.coffee')
  global.constants = require('./constants.coffee')
  global.Logger = require('./logger.coffee')

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
    ancestors = do @getAncestry
    ids = _.map ancestors, (row) -> row.id
    ids.join ", "

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
  - marks datastructures
also deals with loading the initial data from the datastore, and serializing the data to a string

Currently, the separation between the View and Data classes is not very good.  (see view.coffee)
###
class Data
  root: do Row.getRoot

  constructor: (store) ->
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

  #########
  # marks #
  #########

  # get mark for an id, '' if it doesn't exist
  getMark: (id) ->
    marks = @store.getMarks id
    return marks[id] or ''

  # tries to update allMarks with (id, mark)
  # can return false if the mark was already taken
  _updateAllMarks: (id, mark = '') ->
    allMarks = do @store.getAllMarks

    if mark of allMarks
      if allMarks[mark] == id
        return true
      return false

    oldmark = @getMark id
    if oldmark
      delete allMarks[oldmark]

    if mark
      allMarks[mark] = id
    @store.setAllMarks allMarks
    return true

  _updateMark: (id, markId, mark) ->
    marks = @store.getMarks id
    if mark
      marks[markId] = mark
    else
      delete marks[markId]
    @store.setMarks id, marks

  # Set the mark for the entire database id
  setMark: (id, mark = '') ->
    if @_updateAllMarks id, mark
      @_updateMark id, id, mark
      for ancestorId in @allAncestors id
        @_updateMark ancestorId, id, mark
      return true
    return false

  # detach the marks of an row that is being detached
  _detachMarks: (id, delta_ancestry) ->
    marks = @store.getMarks id
    wasLast = (@_getParents id).length == 0

    for markIdStr, mark of marks
      markId = parseInt markIdStr
      if wasLast
        @_updateAllMarks markId, ''
      # Remove the mark from all ancestors of the id which will no longer be ancestors once this Row is removed.
      for ancestorId in delta_ancestry
        @_updateMark ancestorId, markId, ''

  _attachMarks: (id) ->
    marks = @store.getMarks id
    for markIdStr, mark of marks
      markId = parseInt markIdStr
      if not (@setMark markId, mark) # Sets all ancestors regardless of current value
        # Roll back mark on all descendents
        @_removeMarkFromTree id, markId, mark

  # Helper method for attachMarks rollback. Rolls back exactly one id:mark pair from a subtree in O(marked-nodes) time
  _removeMarkFromTree: (id, markId, mark) ->
    marks = @store.getMarks id
    if markId of marks
      errors.assert_equals marks[markId], mark, "Unexpected mark"
      @_updateMark id, markId, ''
      for child in @store.getChildren id
        @_removeMarkFromTree child, markId, mark

  getAllMarks: () ->
    _.mapValues (do @store.getAllMarks), @canonicalInstance, @

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
    (@_getParents id).length > 1

  # Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
  canonicalInstance: (id) -> # Given an id (for example with search or mark), return a row with that id
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
  # Includes 'id' itself unless options.inclusive is specified
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

  # whether currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable: (row) ->
    return (not @collapsed row) or (row.is @viewRoot)

  detach: (row) ->
    # detach a block from the graph
    # though it is detached, it remembers its old parent
    # and remembers its old mark

    original_ancestry = @allAncestors row.id, { inclusive: true }

    parent = do row.getParent
    children = @getSiblings row
    ci = @indexOf row
    children.splice ci, 1
    parents = @_getParents row.id
    pi = _.findIndex parents, (par) ->
        par == parent.id
    parents.splice pi, 1

    @setChildren parent, children
    @_setParents row.id, parents

    new_ancestry = @allAncestors row.id, { inclusive: true }
    delta_ancestry = _.difference original_ancestry, new_ancestry

    # Requires parent to be removed
    @_detachMarks row.id, delta_ancestry

    return {
      parent: parent
      index: ci
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

  # takes id, [id], and attaches each of the ids to the row
  _attachChildren: (parent, new_children, index = -1) ->
    children = @_getChildren parent
    if index == -1
      children.push.apply children, new_children
    else
      children.splice.apply children, [index, 0].concat(new_children)
    @_setChildren parent, children

    for child in new_children
      parents = @_getParents child
      parents.push parent
      @_setParents child, parents

    for child in new_children
      @_attachMarks child

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

  # checks whether inserting a clone of row under parent would create a cycle
  # Precondition: tree is not already circular
  #
  # It is sufficient to check if the row is an ancestor of the new parent,
  # because if there was a clone underneath the row which was an ancestor of 'parent',
  # then 'row' would also be an ancestor of 'parent'.
  wouldBeCircularInsert: (parent, id) ->
    _.contains (@allAncestors parent.id, { inclusive: true }), id

  wouldBeDoubledSiblingInsert: (parent, id) ->
    (@findChild parent, id)?

  # returns whether a row is actually reachable from the root node
  # if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached: (row) ->
    # TODO: Refactor where this is used in light of cloning
    while true
      if do row.isRoot
        return true
      if (@indexOf row) == -1
        return false
      row = do row.getParent

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
    rows = []

    helper = (row) =>
      rows.push row
      for child in @getChildren row
        helper child
    helper @root
    return rows

  # find marks that start with the prefix
  findMarks: (prefix, nresults = 10) ->
    results = [] # list of rows
    for mark, row of (do @getAllMarks)
      if (mark.indexOf prefix) == 0
        results.push {
          row: row
          mark: mark
        }
        if nresults > 0 and results.length == nresults
          break
    return results

  find: (query, options = {}) ->
    nresults = options.nresults or 10
    case_sensitive = options.case_sensitive

    results = [] # list of (row_id, index) pairs

    canonicalize = (x) ->
      return if options.case_sensitive then x else x.toLowerCase()

    get_words = (char_array) ->
      words =
        (char_array.join '').split(' ')
        .filter((x) -> x.length)
        .map canonicalize
      return words

    query_words = get_words query
    if query.length == 0
      return results

    for row in do @orderedLines
      line = canonicalize (@getText row).join ''
      matches = []
      if _.all(query_words.map ((word) ->
                i = line.indexOf word
                if i >= 0
                  for j in [i...i+word.length]
                    matches.push j
                  return true
                else
                  return false
              ))
        results.push {
          row: row
          matches: matches
        }
      if nresults > 0 and results.length == nresults
        break
    return results

  #################
  # serialization #
  #################

  # important: serialized automatically garbage collects
  serialize: (row = @root, pretty=false) ->
    line = @getLine row
    text = (@getText row).join('')

    struct = {
      text: text
    }
    children = (@serialize childrow, pretty for childrow in @getChildren row)
    if children.length
      struct.children = children

    for property in constants.text_properties
      if _.any (line.map ((obj) -> obj[property]))
        struct[property] = ((if obj[property] then '.' else ' ') for obj in line).join ''
        pretty = false

    if (do row.isRoot) and not (do @viewRoot.isRoot)
      struct.viewRoot = @viewRoot

    if @collapsed row
      struct.collapsed = true

    mark = @getMark row.id
    if mark
      struct.mark = mark

    if pretty
      if children.length == 0 and not mark
        return text
    return struct

  loadTo: (serialized, parent = @root, index = -1) ->
    row = new Row parent, (do @store.getNew)

    if not (do row.isRoot)
      @attachChild parent, row, index
    else
      row.setParent null
      @_setParents row.id, [@root.id]

    if typeof serialized == 'string'
      @setLine row, (serialized.split '')
    else
      line = (serialized.text.split '').map((char) -> {char: char})
      for property in constants.text_properties
        if serialized[property]
          for i, val of serialized[property]
            if val == '.'
              line[i][property] = true

      @setLine row, line
      @store.setCollapsed row.id, serialized.collapsed

      if serialized.mark
        @setMark row.id, serialized.mark

      if serialized.children
        for serialized_child in serialized.children
          @loadTo serialized_child, row

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
