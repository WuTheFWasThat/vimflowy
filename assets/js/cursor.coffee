utils = require './utils.coffee'
constants = require './constants.coffee'
EventEmitter = require './eventEmitter.coffee'

Function::property = (prop, desc) ->
  Object.defineProperty @prototype, prop, desc

###
Cursor represents a cursor within a session
it handles movement logic, insert mode line properties (e.g. bold/italic)
###
class Cursor extends EventEmitter
  constructor: (session, path = null, col = null, moveCol = null) ->
    super
    @session = session
    @document = session.document
    @path = path ? (@document.getChildren @session.viewRoot)[0]
    @col = col ? 0
    @properties = {}
    do @_getPropertiesFromContext

    # -1 means last col
    @moveCol = moveCol ? col

  # virtual getter for row
  @property 'row',
    'get': () -> @path.row

  clone: () ->
    # paths are immutable so this is okay
    return new Cursor @session, @path, @col, @moveCol

  _setPath: (path) ->
    @emit 'rowChange', @path, path
    @path = path

  _setCol: (col) ->
    @emit 'colChange', @col, col
    @col = col

  from: (other) ->
    @_setPath other.path
    @_setCol other.col
    @moveCol = other.moveCol

  # cursorOptions:
  #   - pastEnd:         means whether we're on the column or past it.
  #                      generally true when in insert mode but not in normal mode
  #                      effectively decides whether we can go past last column or not
  #   - pastEndWord:     whether we consider the end of a word to be after the last letter
  #                      is true in normal mode (for de), false in visual (for vex)
  #   - keepProperties:  for movement, whether we should keep italic/bold state

  set: (path, col, cursorOptions) ->
    @_setPath path
    @setCol col, cursorOptions

  setPath: (path, cursorOptions) ->
    @_setPath path
    @_fromMoveCol cursorOptions

  setCol: (moveCol, cursorOptions = {pastEnd: true}) ->
    @moveCol = moveCol
    @_fromMoveCol cursorOptions
    # if moveCol was too far, fix it
    # NOTE: this should happen for setting column, but not path
    if @moveCol >= 0
      @moveCol = @col

  _fromMoveCol: (cursorOptions = {}) ->
    len = @document.getLength @path.row
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
    if @col < (@document.getLength @path.row) - shift
      do @_right

  backIfNeeded: () ->
    if @col > (@document.getLength @path.row) - 1
      do @left

  atVisibleEnd: () ->
    if @col < (@document.getLength @path.row) - 1
      return false
    else
      nextpath = @session.nextVisible @path
      if nextpath != null
        return false
    return true

  nextChar: () ->
    if @col < (@document.getLength @path.row) - 1
      do @_right
      return true
    else
      nextpath = @session.nextVisible @path
      if nextpath != null
        @set nextpath, 0
        return true
    return false

  atVisibleStart: () ->
    if @col > 0
      return false
    else
      prevpath = @session.prevVisible @path
      if prevpath != null
        return false
    return true

  prevChar: () ->
    if @col > 0
      do @_left
      return true
    else
      prevpath = @session.prevVisible @path
      if prevpath != null
        @set prevpath, -1
        return true
    return false

  home: () ->
    @setCol 0
    return @

  end: (cursorOptions = {cursor: {}}) ->
    @setCol (if cursorOptions.pastEnd then -1 else -2)
    return @

  visibleHome: () ->
    if @session.viewRoot.is @session.document.root
      path = @session.nextVisible @session.viewRoot
    else
      path = @session.viewRoot
    @set path, 0
    return @

  visibleEnd: () ->
    path = do @session.lastVisible
    @set path, 0
    return @

  wordRegex = /^[a-z0-9_]+$/i

  isInWhitespace: (path, col) ->
    char = @document.getChar path.row, col
    return utils.isWhitespace char

  isInWord: (path, col, matchChar) ->
    if utils.isWhitespace matchChar
      return false

    char = @document.getChar path.row, col
    if utils.isWhitespace char
      return false

    if wordRegex.test char
      return wordRegex.test matchChar
    else
      return not wordRegex.test matchChar

  getWordCheck: (options, matchChar) ->
    if options.whitespaceWord
      return ((path, col) => not @isInWhitespace path, col)
    else
      return ((path, col) => @isInWord path, col, matchChar)

  beginningWord: (options = {}) ->
    if do @atVisibleStart
      return @
    do @prevChar
    while (not do @atVisibleStart) and @isInWhitespace @path, @col
      do @prevChar

    wordcheck = @getWordCheck options, (@document.getChar @path.row, @col)
    while (@col > 0) and wordcheck @path, (@col-1)
      do @_left
    return @

  endWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor.pastEnd
        do @_right
      return @

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @path, @col
      do @nextChar

    end = (@document.getLength @path.row) - 1
    wordcheck = @getWordCheck options, (@document.getChar @path.row, @col)
    while @col < end and wordcheck @path, (@col+1)
      do @_right

    if options.cursor.pastEndWord
      do @_right

    end = (@document.getLength @path.row) - 1
    if @col == end and options.cursor.pastEnd
      do @_right
    return @

  nextWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor.pastEnd
        do @_right
      return @

    end = (@document.getLength @path.row) - 1
    wordcheck = @getWordCheck options, (@document.getChar @path.row, @col)
    while @col < end and wordcheck @path, (@col+1)
      do @_right

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @path, @col
      do @nextChar

    end = (@document.getLength @path.row) - 1
    if @col == end and options.cursor.pastEnd
      do @_right
    return @

  findNextChar: (char, options = {}) ->
    end = (@document.getLength @path.row) - 1
    if @col == end
      return

    col = @col
    if options.beforeFound
      col += 1

    found = null
    while col < end
      col += 1
      if (@document.getChar @path.row, col) == char
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
      if (@document.getChar @path.row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.beforeFound
      do @_right

  up: (cursorOptions = {}) ->
    path = @session.prevVisible @path
    if path?
      @setPath path, cursorOptions

  down: (cursorOptions = {}) ->
    path = @session.nextVisible @path
    if path?
      @setPath path, cursorOptions

  parent: (cursorOptions = {}) ->
    path = @path.parent
    if path.row == @document.root.row
      return
    if @path.is @session.viewRoot
      @session._changeViewRoot path
    @setPath path, cursorOptions

  prevSibling: (cursorOptions = {}) ->
    prevsib = @document.getSiblingBefore @path
    if prevsib?
      @setPath prevsib, cursorOptions

  nextSibling: (cursorOptions = {}) ->
    nextsib = @document.getSiblingAfter @path
    if nextsib?
      @setPath nextsib, cursorOptions

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
    line = @document.getLine @path.row
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
