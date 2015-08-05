# imports
if module?
  _ = require('underscore')
  utils = require('./utils.coffee')
  constants = require('./constants.coffee')
  Logger = require('./logger.coffee')

class Data
  root: 0

  constructor: (store) ->
    @store = store
    @viewRoot = do @store.getLastViewRoot
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

  getMark: (id) ->
    return (@store.getMark id) || ''

  _updateAllMarks: (id, mark = '') ->
    allMarks = do @store.getAllMarks

    if mark of allMarks
      return false

    oldmark = @store.getMark id
    if oldmark
      delete allMarks[oldmark]

    if mark
      allMarks[mark] = id
    @store.setAllMarks allMarks
    return true

  setMark: (id, mark = '') ->
    # update allMarks mapping
    if @_updateAllMarks id, mark
      # update row's mark
      @store.setMark id, mark

  getAllMarks: () ->
    return do @store.getAllMarks

  #############
  # structure #
  #############

  getParent: (row) ->
    return @store.getParent row

  getChildren: (row) ->
    return @store.getChildren row

  hasChildren: (row) ->
    return ((@getChildren row).length > 0)

  getSiblings: (row) ->
    parent = @getParent row
    return @getChildren parent

  collapsed: (row) ->
    return @store.getCollapsed row

  toggleCollapsed: (id) ->
    @store.setCollapsed id, (not @collapsed id)

  # whether currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable: (row) ->
    return (not @collapsed row) or (row == @viewRoot)

  indexOf: (child) ->
    children = @getSiblings child
    return children.indexOf child

  detach: (id) ->
    # detach a block from the graph
    # though it is detached, it remembers its old parent
    # and remembers its old mark

    parent = @getParent id
    children = @getChildren parent
    i = children.indexOf id
    children.splice i, 1

    @store.setChildren parent, children

    mark = @getMark id
    if mark
      # set the mark in allMarks, but not for the row
      # that way, when re-attaching, we can try to re-apply the mark
      @_updateAllMarks id, ''

    return {
      parent: parent
      index: i
    }

  # attaches a detached child to a parent
  # the child should not have a parent already
  attachChild: (id, child, index = -1) ->
    @attachChildren id, [child], index

  attachChildren: (id, new_children, index = -1) ->
    children = @getChildren id
    if index == -1
      children.push.apply children, new_children
    else
      children.splice.apply children, [index, 0].concat(new_children)
    for child in new_children
      @store.setParent child, id

      # try to restore the mark of child
      mark = @getMark child
      if mark
        if not (@_updateAllMarks child, mark)
          # don't call @setMark, since that will mess up allMarks
          @store.setMark child, ''

    @store.setChildren id, children

  nextVisible: (id = @viewRoot) ->
    if @viewable id
      children = @getChildren id
      if children.length > 0
        return children[0]
    while true
      nextsib = @getSiblingAfter id
      if nextsib != null
        return nextsib
      id = @getParent id
      if id == @viewRoot
        return null

  # last thing visible nested within id
  lastVisible: (id = @viewRoot) ->
    if not @viewable id
      return id
    children = @getChildren id
    if children.length > 0
      return @lastVisible children[children.length - 1]
    return id

  prevVisible: (id) ->
    prevsib = @getSiblingBefore id
    if prevsib != null
      return @lastVisible prevsib
    parent = @getParent id
    if parent == @viewRoot
      return null
    return parent

  # finds oldest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  oldestVisibleAncestor: (id) ->
    last = id
    while true
      cur = @getParent last
      if cur == @viewRoot
        return last
      if cur == @root
        return null
      last = cur

  # finds closest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  youngestVisibleAncestor: (id) ->
    answer = id
    cur = id
    while true
      cur = @getParent cur
      if cur == @viewRoot
        return answer
      if cur == @root
        return null
      if @collapsed cur
        answer = cur

  # returns whether a row is actually reachable from the root node
  # if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached: (id) ->
    while true
      if id == @root
        return true
      if (@indexOf id) == -1
        return false
      id = @getParent id

  getSiblingBefore: (id) ->
    return @getSiblingOffset id, -1

  getSiblingAfter: (id) ->
    return @getSiblingOffset id, 1

  getSiblingOffset: (id, offset) ->
    return (@getSiblingRange id, offset, offset)[0]

  getSiblingRange: (id, min_offset, max_offset) ->
    children = @getSiblings id
    index = @indexOf id
    return @getChildRange (@getParent id), (min_offset + index), (max_offset + index)

  getChildRange: (id, min, max) ->
    children = @getChildren id
    indices = [min..max]

    return indices.map (index) ->
      if index >= children.length
        return null
      else if index < 0
        return null
      else
        return children[index]

  addChild: (id, index = -1) ->
    child = do @store.getNew
    @attachChild id, child, index
    return child

  # this is never used, since data structure is basically persistent
  # deleteRow: (id) ->
  #   if id == @viewRoot
  #     throw 'Cannot delete view root'

  #   for child in (@getChildren id).slice()
  #     @deleteRow child

  #   @detach id
  #   @store.delete id

  _insertSiblingHelper: (id, after) ->
    if id == @viewRoot
      Logger.logger.error 'Cannot insert sibling of view root'
      return null

    parent = @getParent id
    children = @getChildren parent
    index = children.indexOf id

    return (@addChild parent, (index + after))

  insertSiblingAfter: (id) ->
    return @_insertSiblingHelper id, 1

  insertSiblingBefore: (id) ->
    return @_insertSiblingHelper id, 0

  orderedLines: () ->
    ids = []

    helper = (id) =>
      ids.push id
      for child in @getChildren id
        helper child
    helper @root
    return ids

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

    for id in do @orderedLines
      line = canonicalize (@getText id).join ''
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
          row: id
          matches: matches
        }
      if nresults > 0 and results.length == nresults
        break
    return results

  #################
  # serialization #
  #################

  # important: serialized automatically garbage collects
  serialize: (id = @root, pretty=false) ->
    line = @getLine id
    text = (@getText id).join('')

    struct = {
      text: text
    }
    children = (@serialize childid, pretty for childid in @getChildren id)
    if children.length
      struct.children = children

    for property in constants.text_properties
      if _.any (line.map ((obj) -> obj[property]))
        struct[property] = ((if obj[property] then '.' else ' ') for obj in line).join ''
        pretty = false

    if id == @root and @viewRoot != @root
      struct.viewRoot = @viewRoot

    if @collapsed id
      struct.collapsed = true

    mark = @store.getMark id
    if mark
      struct.mark = mark

    if pretty
      if children.length == 0 and not mark
        return text
    return struct

  loadTo: (serialized, parent = @root, index = -1) ->
    id = do @store.getNew

    if id != @root
      @attachChild parent, id, index
    else
      # parent should be 0
      @store.setParent id, @root

    if typeof serialized == 'string'
      @setLine id, (serialized.split '')
    else
      line = (serialized.text.split '').map((char) -> {char: char})
      for property in constants.text_properties
        if serialized[property]
          for i, val of serialized[property]
            if val == '.'
              line[i][property] = true

      @setLine id, line
      @store.setCollapsed id, serialized.collapsed

      if serialized.mark
        @setMark id, serialized.mark

      if serialized.children
        for serialized_child in serialized.children
          @loadTo serialized_child, id

    return id

  load: (serialized) ->
    if serialized.viewRoot
      @viewRoot = serialized.viewRoot
    else
      @viewRoot = @root

    @loadTo serialized

# exports
module?.exports = Data
