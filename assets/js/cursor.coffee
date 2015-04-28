class Cursor
  constructor: (data, row = 1, col = 0) ->
    @data = data
    @row = row
    @col = col

  clone: () ->
    return new Cursor @data, @row, @col

  left: () ->
    if @col > 0
      @col -= 1

  right: (options) ->
    options?={}
    shift = if options.cursor == 'pastEnd' then 0 else 1
    if @col < (@data.rowLength @row) - shift
      @col += 1

  home: () ->
    @col = 0

  end: (options) ->
    options ?= {}
    shift = if options.cursor == 'pastEnd' then 0 else 1
    @col = (@data.rowLength @row) - shift

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
    @col -= 1
    while @col > 0 and @isInWhitespace @row, @col
      @col -= 1

    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col > 0 and wordcheck @row, (@col-1)
      @col -= 1

  endWord: (options = {}) ->
    end = (@data.rowLength @row) - 1
    if @col == end
      if options.cursor == 'pastEnd'
        @col += 1
      return

    @col += 1
    while @col < end and @isInWhitespace @row, @col
      @col += 1
    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      @col += 1

    if options.cursor == 'pastEnd'
      @col += 1

  nextWord: (options = {}) ->
    end = (@data.rowLength @row) - 1
    if @col == end
      if options.cursor == 'pastEnd'
        @col += 1
      return

    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      @col += 1
    while @col < end and @isInWhitespace @row, (@col+1)
      @col += 1

    if @col < end or options.cursor == 'pastEnd'
      @col += 1

  nextChar: (char, options = {}) ->
    end = (@data.rowLength @row) - 1
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

    @col = found
    if options.cursor == 'pastEnd'
      @col += 1
    if options.beforeFound
      @col -= 1

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

    @col = found
    if options.beforeFound
      @col += 1

  up: () ->
    row = @data.prevVisible @row
    if row != null
      @row = row
      @col = 0

  down: () ->
    row = @data.nextVisible @row
    if row != null
      @row = row
      @col = 0

# exports
module?.exports = Cursor
