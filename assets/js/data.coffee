# imports
if module?
  global._ = require('lodash')
  global.utils = require('./utils.coffee')
  global.errors = require('./errors.coffee')
  global.constants = require('./constants.coffee')
  global.Logger = require('./logger.coffee')

class Instance
  constructor: (@parent, @id, @datastore_object=null) ->

  getParent: () ->
    @parent

  setParent: (parent) ->
    @parent = parent

  getId: () ->
    @id

  debug: () ->
    ancestors = do @getAncestry
    ids = _.map ancestors, (row) -> row.id
    ids.join ", "

  isRoot: () ->
    @id == constants.root_id

  clone: () ->
    new Instance (@parent?.clone?()), @id, (_.cloneDeep @datastore_object)

  # Represents the exact same view instance
  is: (other) ->
    [row1, row2] = [@, other]
    while row1.id == row2.id and not (do row1.isRoot) and not (do row2.isRoot)
      row1 = do row1.getParent
      row2 = do row2.getParent
    return row1.id == row2.id

Instance.getRoot = () ->
  root = new Instance {}, constants.root_id, {}
  root.setParent null
  root

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
  rootId: constants.root_id
  root: do Instance.getRoot

  constructor: (store) ->
    @store = store
    @viewRoot = do @store.getLastViewRoot || @root
    return @

  changeViewRoot: (row) ->
    @viewRoot = row
    @store.setLastViewRoot row

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

  # get mark for a row, '' if it doesn't exist
  getMark: (row) ->
    marks = @store.getMarks row.id
    return marks[row.id] or ''

  _updateAllMarks: (row, mark = '') ->
    allMarks = do @store.getAllMarks

    if mark of allMarks
      if allMarks[mark] == row.id
        return true
      return false

    oldmark = @getMark row
    if oldmark
      delete allMarks[oldmark]

    if mark
      allMarks[mark] = row.id
    @store.setAllMarks allMarks
    return true

  # recursively update allMarks for id,mark pair
  _updateMarksRecursive: (row, mark = '', from, to) ->
    cur = from
    while true
      marks = @store.getMarks cur.id
      if mark
        marks[row.id] = mark
      else
        delete marks[row.id]
      @store.setMarks cur.id, marks
      if cur.id == to.id
        break
      cur = do cur.getParent

  setMark: (row, mark = '') ->
    if @_updateAllMarks row, mark
      @_updateMarksRecursive row, mark, row, @root
      return true
    return false

  # detach the marks of an id that is being detached
  # assumes that the old parent of the id is set
  detachMarks: (row) ->
    marks = @store.getMarks row.id
    for id, mark of marks
      id = parseInt id
      row2 = @canonicalInstance id
      @_updateAllMarks row2, ''
      # roll back the mark for this row, but only above me
      @_updateMarksRecursive row2, '', (do row.getParent), @root

  # try to restore the marks of an id that was detached
  # assumes that the new to-be-parent of the id is already set
  # and that the marks dictionary contains the old values
  attachMarks: (row) ->
    marks = @store.getMarks row.id
    for id, mark of marks
      id = parseInt id
      row2 = @canonicalInstance id
      if not (@setMark row2, mark)
        # roll back the mark for this row, but only underneath me
        @_updateMarksRecursive row2, '', row2, row

  getAllMarks: () ->
    _.mapValues (do @store.getAllMarks), @canonicalInstance, @

  #############
  # structure #
  #############

  getChildren: (row) ->
    children = @store.getChildren row.id
    _.map children, (child) ->
      new Instance row, child.id, child

  getChild: (row, id) ->
    _.find (@getChildren row), (x) -> x.id == id

  getParents: (row) ->
    return @store.getParents row.id

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

  countInstances: (id) ->
    # Precondition: No circular references in ancestry
    errors.assert id?, "Empty id passed to countInstances"
    if id == @root.id
      return 1
    parentCount = 0
    for parent_id in (@store.getParents id)
      parentCount += @countInstances parent_id # Always exactly once under every parent
    return parentCount

  exactlyOneInstance: (id) ->
    1 == @countInstances id

  canonicalInstance: (id) -> # Given an id (for example with search or mark), return a row with that id
    # TODO: Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
    # This probably isn't as performant as it could be for how often it gets called, but I'd rather make it called less often before optimizing.
    errors.assert id?, "Empty id passed to canonicalInstance"
    if id == @root.id
      return @root
    parentId = (@store.getParents id)[0] # This is the only actual choice made
    errors.assert parentId?, "No parent found for id: #{id}"
    canonicalParent = @canonicalInstance parentId
    instance = @getChild canonicalParent, id
    errors.assert instance?, "No canonical instance found for id: #{id}"
    return instance

  # whether currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable: (row) ->
    return (not @collapsed row) or (row.is @viewRoot)

  detach: (row) ->
    # detach a block from the graph
    # though it is detached, it remembers its old parent
    # and remembers its old mark

    if @exactlyOneInstance row.id # If detaching the LAST instance
      @detachMarks row # Requires parent to be set correctly, so it's at the beginning

    parent = do row.getParent
    children = @getSiblings row
    ci = @indexOf row
    children.splice ci, 1
    parents = @getParents row
    pi = _.findIndex parents, (par) ->
        par == parent.id
    parents.splice pi, 1

    @store.setChildren parent.id, children
    @store.setParents row.id, parents

    return {
      parent: parent
      index: ci
    }

  # attaches a detached child to a parent
  # the child should not have a parent already
  attachChild: (row, child, index = -1) ->
    children = @attachChildren row, [child], index
    return children[0]

  attachChildren: (row, new_children, index = -1) ->
    children = @getChildren row
    if index == -1
      children.push.apply children, new_children
    else
      children.splice.apply children, [index, 0].concat(new_children)
    for child in new_children
      if @wouldBeCircularInsert child, row
        throw new errors.CircularReference "Trying to attach a child as a descendent of itself"
      child.setParent row
      parents = @store.getParents child.id
      parents.push row.id
      @store.setParents child.id, parents
    @store.setChildren row.id, children

    for child in new_children
      @attachMarks child
    return new_children

  # returns an array representing the ancestry of a row,
  # up until the ancestor specified by the `stop` parameter
  # i.e. [stop, stop's child, ... , row's parent , row]
  getAncestry: (row, stop = @root) ->
    ancestors = []
    until row.is stop
      errors.assert_not_equals row.id, @root.id, "Failed to get ancestry for #{row} going up until #{stop}"
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

  combineAncestry: (row, descendents) ->
    for descendent in descendents
      row = @getChild row, descendent.id
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
      if cur.id == @root.id
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
      if cur.id == @root.id
        return null
      if @collapsed cur
        answer = cur

  # Checks whether the ancestor is visible. Does not include the given node but does
  # include viewRoot
  hasVisibleAncestor: (row, checkAncestorId) ->
    errors.assert row?
    errors.assert checkAncestorId?
    cur = row
    until (cur.is @viewRoot) or (do cur.isRoot)
      cur = do cur.getParent
      if cur.id == checkAncestorId
        return true
    return false
  wouldBeCircularInsert: (row, parent) ->
    return parent.id == row.id or (@hasVisibleAncestor parent, row.id)

  # returns whether a row is actually reachable from the root node
  # if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached: (row) ->
    # TODO: Refactor where this is used in light of cloning
    while true
      if row.id == @root.id
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
    child = new Instance row, id
    @attachChild row, child, index
    return child

  cloneRow: (row, parent, index = -1) ->
    @attachChild parent, (do row.clone), index

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

    if row.id == @root.id and @viewRoot.id != @root.id
      struct.viewRoot = @viewRoot

    if @collapsed row
      struct.collapsed = true

    mark = @getMark row
    if mark
      struct.mark = mark

    if pretty
      if children.length == 0 and not mark
        return text
    return struct

  loadTo: (serialized, parent = @root, index = -1) ->
    row = new Instance parent, (do @store.getNew), {}

    if row.id != @root.id
      @attachChild parent, row, index
    else
      row.setParent null
      @store.setParents row.id, [@root.id]

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
        @setMark row, serialized.mark

      if serialized.children
        for serialized_child in serialized.children
          @loadTo serialized_child, row

    return row

  load: (serialized) ->
    if serialized.viewRoot
      @viewRoot = serialized.viewRoot # TODO: Serialize and unserialize viewRoot in terms of id-list only
    else
      @viewRoot = @root

    @loadTo serialized

# exports
module?.exports = Data
window?.Data = Data
