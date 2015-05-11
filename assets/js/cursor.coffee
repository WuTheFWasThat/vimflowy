class Cursor
  constructor: (data, row = null, col = null, moveCol = null) ->
    @data = data
    @row = if row == null then (@data.getChildren @data.viewRoot)[0] else row
    @col = if col == null then 0 else col
    console.log('CURSOR"', @row, @col)

    # -1 means last col
    @moveCol = if moveCol == null then col else moveCol

  clone: () ->
    return new Cursor @data, @row, @col, @moveCol

  set: (row, col) ->
    @setRow row
    @setCol col

  setRow: (row) ->
    @row = row

  setCol: (moveCol) ->
    @moveCol = moveCol
    rowlen = @data.getLength @row

    if moveCol < 0
      @col = rowlen + moveCol + 1
    else
      @col = moveCol

  fromMoveCol: (option) ->
    len = @data.getLength @row
    maxcol = len - (if option == 'pastEnd' then 0 else 1)
    if @moveCol < 0
      @col = len + @moveCol + 1
    else
      @col = Math.max(0, Math.min(maxcol, @moveCol))

  _left: () ->
    @setCol (@col - 1)

  _right: () ->
    @setCol (@col + 1)

  left: () ->
    if @col > 0
      do @_left

  right: (options) ->
    options?={}
    shift = if options.cursor == 'pastEnd' then 0 else 1
    if @col < (@data.getLength @row) - shift
      do @_right

  home: () ->
    @setCol 0

  end: (options = {}) ->
    @setCol (if options.cursor == 'pastEnd' then -1 else -2)

  wordRegex = /^[a-z0-9_]+$/i

  isWhitespace = (char) ->
    return char == ' '

  isInWhitespace: (row, col) ->
    char = @data.getChar row, col
    return isWhitespace char

  isInWord: (row, col, matchChar) ->
    if isWhitespace matchChar
      return false

    char = @data.getChar row, col
    if isWhitespace char
      return false

    if wordRegex.test char
      return wordRegex.test matchChar
    else
      return not wordRegex.test matchChar

  getWordCheck: (options, matchChar) ->
    if options.block
      return ((row, col) => not @isInWhitespace row, col)
    else
      return ((row, col) => @isInWord row, col, matchChar)

  beginningWord: (options = {}) ->
    if @col == 0
      return
    do @_left
    while @col > 0 and @isInWhitespace @row, @col
      do @_left

    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col > 0 and wordcheck @row, (@col-1)
      do @_left

  endWord: (options = {}) ->
    end = (@data.getLength @row) - 1
    if @col == end
      if options.cursor == 'pastEnd'
        do @_right
      return

    do @_right
    while @col < end and @isInWhitespace @row, @col
      do @_right
    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    if options.cursor == 'pastEnd'
      do @_right

  nextWord: (options = {}) ->
    end = (@data.getLength @row) - 1
    if @col == end
      if options.cursor == 'pastEnd'
        do @_right
      return

    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right
    while @col < end and @isInWhitespace @row, (@col+1)
      do @_right

    if @col < end or options.cursor == 'pastEnd'
      do @_right

  nextChar: (char, options = {}) ->
    end = (@data.getLength @row) - 1
    if @col == end
      return

    col = @col
    if options.beforeFound
      col += 1

    found = null
    while col < end
      col += 1
      if (@data.getChar @row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.cursor == 'pastEnd'
      do @_right
    if options.beforeFound
      do @_left

  prevChar: (char, options = {}) ->
    if @col == 0
      return

    col = @col
    if options.beforeFound
      col -= 1

    found = null
    while col > 0
      col -= 1
      if (@data.getChar @row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.beforeFound
      do @_right

  up: (options) ->
    row = @data.prevVisible @row
    if row != null
      @row = row
      @fromMoveCol options.cursor

  down: (options) ->
    row = @data.nextVisible @row
    if row != null
      @row = row
      @fromMoveCol options.cursor

# exports
module?.exports = Cursor
