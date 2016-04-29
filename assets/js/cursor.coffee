utils = require './utils.coffee'
constants = require './constants.coffee'
EventEmitter = require './eventEmitter.coffee'

###
Cursor represents a cursor within a session
it handles movement logic, insert mode line properties (e.g. bold/italic)
###
class Cursor extends EventEmitter
  constructor: (session, row = null, col = null, moveCol = null) ->
    super
    @session = session
    @document = session.document
    @row = row ? (@document.getChildren @session.viewRoot)[0]
    @col = col ? 0
    @properties = {}
    do @_getPropertiesFromContext

    # -1 means last col
    @moveCol = moveCol ? col

  clone: () ->
    return new Cursor @session, (do @row.clone), @col, @moveCol

  _setRow: (row) ->
    @emit 'rowChange', @row, row
    @row = row

  _setCol: (col) ->
    @emit 'colChange', @col, col
    @col = col

  from: (other) ->
    @_setRow other.row
    @_setCol other.col
    @moveCol = other.moveCol

  # cursorOptions:
  #   - pastEnd:         means whether we're on the column or past it.
  #                      generally true when in insert mode but not in normal mode
  #                      effectively decides whether we can go past last column or not
  #   - pastEndWord:     whether we consider the end of a word to be after the last letter
  #                      is true in normal mode (for de), false in visual (for vex)
  #   - keepProperties:  for movement, whether we should keep italic/bold state

  set: (row, col, cursorOptions) ->
    @_setRow row
    @setCol col, cursorOptions

  setRow: (row, cursorOptions) ->
    @_setRow row
    @_fromMoveCol cursorOptions

  setCol: (moveCol, cursorOptions = {pastEnd: true}) ->
    @moveCol = moveCol
    @_fromMoveCol cursorOptions
    # if moveCol was too far, fix it
    # NOTE: this should happen for setting column, but not row
    if @moveCol >= 0
      @moveCol = @col

  _fromMoveCol: (cursorOptions = {}) ->
    len = @document.getLength @row
    maxcol = len - (if cursorOptions.pastEnd then 0 else 1)
    if @moveCol < 0
      col = Math.max(0, len + @moveCol + 1)
    else
      col = Math.max(0, Math.min(maxcol, @moveCol))
    @_setCol col
    if not cursorOptions.keepProperties
      do @_getPropertiesFromContext

  _left: () ->
    @setCol (@col - 1)

  _right: () ->
    @setCol (@col + 1)

  left: () ->
    if @col > 0
      do @_left

  right: (cursorOptions = {}) ->
    shift = if cursorOptions.pastEnd then 0 else 1
    if @col < (@document.getLength @row) - shift
      do @_right

  backIfNeeded: () ->
    if @col > (@document.getLength @row) - 1
      do @left

  atVisibleEnd: () ->
    if @col < (@document.getLength @row) - 1
      return false
    else
      nextrow = @session.nextVisible @row
      if nextrow != null
        return false
    return true

  nextChar: () ->
    if @col < (@document.getLength @row) - 1
      do @_right
      return true
    else
      nextrow = @session.nextVisible @row
      if nextrow != null
        @set nextrow, 0
        return true
    return false

  atVisibleStart: () ->
    if @col > 0
      return false
    else
      prevrow = @session.prevVisible @row
      if prevrow != null
        return false
    return true

  prevChar: () ->
    if @col > 0
      do @_left
      return true
    else
      prevrow = @session.prevVisible @row
      if prevrow != null
        @set prevrow, -1
        return true
    return false

  home: () ->
    @setCol 0
    return @

  end: (cursorOptions = {cursor: {}}) ->
    @setCol (if cursorOptions.pastEnd then -1 else -2)
    return @

  visibleHome: () ->
    row = do @session.nextVisible
    @set row, 0
    return @

  visibleEnd: () ->
    row = do @session.lastVisible
    @set row, 0
    return @

  wordRegex = /^[a-z0-9_]+$/i

  isInWhitespace: (row, col) ->
    char = @document.getChar row, col
    return utils.isWhitespace char

  isInWord: (row, col, matchChar) ->
    if utils.isWhitespace matchChar
      return false

    char = @document.getChar row, col
    if utils.isWhitespace char
      return false

    if wordRegex.test char
      return wordRegex.test matchChar
    else
      return not wordRegex.test matchChar

  getWordCheck: (options, matchChar) ->
    if options.whitespaceWord
      return ((row, col) => not @isInWhitespace row, col)
    else
      return ((row, col) => @isInWord row, col, matchChar)

  beginningWord: (options = {}) ->
    if do @atVisibleStart
      return @
    do @prevChar
    while (not do @atVisibleStart) and @isInWhitespace @row, @col
      do @prevChar

    wordcheck = @getWordCheck options, (@document.getChar @row, @col)
    while (@col > 0) and wordcheck @row, (@col-1)
      do @_left
    return @

  endWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor.pastEnd
        do @_right
      return @

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @row, @col
      do @nextChar

    end = (@document.getLength @row) - 1
    wordcheck = @getWordCheck options, (@document.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    if options.cursor.pastEndWord
      do @_right

    end = (@document.getLength @row) - 1
    if @col == end and options.cursor.pastEnd
      do @_right
    return @

  nextWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor.pastEnd
        do @_right
      return @

    end = (@document.getLength @row) - 1
    wordcheck = @getWordCheck options, (@document.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @row, @col
      do @nextChar

    end = (@document.getLength @row) - 1
    if @col == end and options.cursor.pastEnd
      do @_right
    return @

  findNextChar: (char, options = {}) ->
    end = (@document.getLength @row) - 1
    if @col == end
      return

    col = @col
    if options.beforeFound
      col += 1

    found = null
    while col < end
      col += 1
      if (@document.getChar @row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.cursor.pastEnd
      do @_right
    if options.beforeFound
      do @_left

  findPrevChar: (char, options = {}) ->
    if @col == 0
      return

    col = @col
    if options.beforeFound
      col -= 1

    found = null
    while col > 0
      col -= 1
      if (@document.getChar @row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.beforeFound
      do @_right

  up: (cursorOptions = {}) ->
    row = @session.prevVisible @row
    if row?
      @setRow row, cursorOptions

  down: (cursorOptions = {}) ->
    row = @session.nextVisible @row
    if row?
      @setRow row, cursorOptions

  parent: (cursorOptions = {}) ->
    row = do @row.getParent
    if row.id == @document.root.id
      return
    if row.is @session.viewRoot
      @session.changeViewRoot (do row.getParent)
    @setRow row, cursorOptions

  prevSibling: (cursorOptions = {}) ->
    prevsib = @document.getSiblingBefore @row
    if prevsib?
      @setRow prevsib, cursorOptions

  nextSibling: (cursorOptions = {}) ->
    nextsib = @document.getSiblingAfter @row
    if nextsib?
      @setRow nextsib, cursorOptions

  # cursor properties

  setProperty: (property, value) ->
    @properties[property] = value

  getProperty: (property) ->
    return @properties[property]

  toggleProperty: (property) ->
    @setProperty property, (not (@getProperty property))

  # get whether the cursor should be bold/italic based on surroundings
  # NOTE: only relevant for insert mode.
  _getPropertiesFromContext: () ->
    line = @document.getLine @row
    if line.length == 0
      obj = {}
    else if @col == 0
      obj = line[@col]
    else
      obj = line[@col-1]
    for property in constants.text_properties
      @setProperty property, obj[property]

# exports
module.exports = Cursor
