# imports
if module?
  _ = require('underscore')
  utils = require('./utils.coffee')
  constants = require('./constants.coffee')
  Logger = require('./logger.coffee')

class Data
  root:
    id: 0
    crumbs: { parent: 0, crumbs: { parent: 0 } } # make it enough layers to guard against any bugs, but not circular because serialization

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
      cur = @getParent cur

  setMark: (row, mark = '') ->
    if @_updateAllMarks row, mark
      @_updateMarksRecursive row, mark, row, @root
      return true
    return false

  # detach the marks of an id that is being detached
  # assumes that the old parent of the id is set
  detachMarks: (row) ->
    marks = @store.getMarks row.id
    for childId, mark of marks
      childRow = { id: childId, crumbs: { parent: row.id, crumbs: row.crumbs } }
      @_updateAllMarks childRow, ''
      # roll back the mark for this row, but only above me
      @_updateMarksRecursive childRow, '', (@getParent row), @root

  # try to restore the marks of an id that was detached
  # assumes that the new to-be-parent of the id is already set
  # and that the marks dictionary contains the old values
  attachMarks: (row) ->
    marks = @store.getMarks row.id
    for childId, mark of marks
      childRow = { id: childId, crumbs: { parent: row.id, crumbs: row.crumbs } }
      if not (@setMark childRow, mark)
        # roll back the mark for this row, but only underneath me
        @_updateMarksRecursive childRow, '', childRow, row

  getAllMarks: () ->
    _.mapObject (do @store.getAllMarks), @canonicalInstance, @

  #############
  # structure #
  #############

  getParent: (row) ->
    return { id: row.crumbs.parent, crumbs: row.crumbs.crumbs }

  getParents: (row) ->
    return @store.getParents row.id

  getChildren: (row) ->
    children = @store.getChildren row.id
    _.each children, (child) ->
      child.crumbs = { parent: row.id, crumbs: row.crumbs }
    return children

  hasChildren: (row) ->
    return ((@getChildren row).length > 0)

  getSiblings: (row) ->
    children = @store.getChildren row.crumbs.parent
    _.each children, (child) ->
      child.crumbs = row.crumbs
    return children

  collapsed: (row) ->
    return @store.getCollapsed row.id

  canonicalInstance: (id, mark) -> # Given an id (for example with search or mark), return a row with that id
    # TODO: try to optimize for one in the viewroot
    # This probably isn't as performant as it could be for how often it gets called, but I'd rather make it called less often before optimizing.
    unless id? then return
    if id == @root.id
      return @root
    parentId = (@store.getParents id)[0]
    canonicalParent = @canonicalInstance parentId
    if not canonicalParent
      return
    children = @getChildren canonicalParent
    return _.find children, (sib) ->
      sib.id == id

  toggleCollapsed: (row) ->
    @store.setCollapsed row.id, (not @collapsed row)

  # whether currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable: (row) ->
    return (not @collapsed row) or (row.id == @viewRoot.id)

  indexOf: (child) ->
    children = @getSiblings child
    return _.findIndex children, (sib) ->
        sib.id == child.id

  detach: (row) ->
    # detach a block from the graph
    # though it is detached, it remembers its old parent
    # and remembers its old mark

    parent = @getParent row
    children = @getSiblings row
    ci = @indexOf row
    children.splice ci, 1
    parents = @getParents row
    pi = _.findIndex parents, (par) ->
        par == parent.id
    parents.splice pi, 1

    @store.setChildren parent.id, children
    @store.setParents row.id, parents
    @detachMarks row

    return {
      parent: parent
      index: ci
    }

  # attaches a detached child to a parent
  # the child should not have a parent already
  attachChild: (row, child, index = -1) ->
    @attachChildren row, [child], index

  attachChildren: (row, new_children, index = -1) ->
    children = @getChildren row
    if index == -1
      children.push.apply children, new_children
    else
      children.splice.apply children, [index, 0].concat(new_children)
    for child in new_children
      child.crumbs = { parent: row.id, crumbs: row.crumbs }
      parents = @store.getParents child.id
      parents.push row.id
      @store.setParents child.id, row.id
      @attachMarks child

    @store.setChildren row.id, children

  nextVisible: (row = @viewRoot) ->
    if @viewable row
      children = @getChildren row
      if children.length > 0
        return children[0]
    while true
      nextsib = @getSiblingAfter row
      if nextsib != null
        return nextsib
      row = @getParent row
      if row.id == @viewRoot.id
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
    if prevsib != null
      return @lastVisible prevsib
    parent = @getParent row
    if parent.id == @viewRoot.id
      return null
    return parent

  # finds oldest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  oldestVisibleAncestor: (row) ->
    last = row
    while true
      cur = @getParent last
      if cur.id == @viewRoot.id
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
      cur = @getParent cur
      if cur.id == @viewRoot.id
        return answer
      if cur.id == @root.id
        return null
      if @collapsed cur
        answer = cur

  # returns whether a row is actually reachable from the root node
  # if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached: (row) ->
    # TODO: Refactor where this is used in light of cloning
    while true
      if row.id == @root.id
        return true
      if (@indexOf row) == -1
        return false
      row = @getParent row

  getSiblingBefore: (row) ->
    return @getSiblingOffset row, -1

  getSiblingAfter: (row) ->
    return @getSiblingOffset row, 1

  getSiblingOffset: (row, offset) ->
    return (@getSiblingRange row, offset, offset)[0]

  getSiblingRange: (row, min_offset, max_offset) ->
    children = @getSiblings row
    index = @indexOf row
    return @getChildRange (@getParent row), (min_offset + index), (max_offset + index)

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
    child = { id: do @store.getNew }
    @attachChild row, child, index
    return child

  # this is never used, since data structure is basically persistent
  # deleteRow: (row) ->
  #   if row.id == @viewRoot.id
  #     throw 'Cannot delete view root'

  #   for child in (@getChildren row).slice()
  #     @deleteRow child

  #   @detach row
  #   @store.delete row.id

  _insertSiblingHelper: (row, after) ->
    if row.id == @viewRoot.id
      Logger.logger.error 'Cannot insert sibling of view root'
      return null

    parent = @getParent row
    children = @getChildren parent
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
      unless row?
        continue
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
    row = { id: do @store.getNew }

    if row.id != @root.id
      @attachChild parent, row, index
    else
      # parent should be 0 == @root.id
      @store.setParents row.id, [@root.id]
      row.crumbs = @root.crumbs

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
      @viewRoot = serialized.viewRoot
    else
      @viewRoot = @root

    @loadTo serialized

# exports
module?.exports = Data
