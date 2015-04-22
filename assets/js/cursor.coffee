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
    shift = if options.pastEnd then 0 else 1
    if @col < (@data.rowLength @row) - shift
      @col += 1

  home: () ->
    @col = 0

  end: (options) ->
    options ?= {}
    shift = if options.pastEnd then 0 else 1
    @col = (@data.rowLength @row) - shift

  beginningWord: () ->
    if @col == 0
      return
    @col -= 1
    while @col > 0 and (@data.getChar @row, @col) == ' '
      @col -= 1
    while @col > 0 and (@data.getChar @row, @col-1) != ' '
      @col -= 1

  endWord: (options = {}) ->
    end = (@data.rowLength @row) - 1
    if @col == end
      if options.pastEnd
        @col += 1
      return

    @col += 1
    while @col < end and (@data.getChar @row, @col) == ' '
      @col += 1
    while @col < end and (@data.getChar @row, @col+1) != ' '
      @col += 1

    if options.pastEnd
      @col += 1

  nextWord: (options = {}) ->
    end = (@data.rowLength @row) - 1
    if @col == end
      if options.pastEnd
        @col += 1
      return

    while @col < end and (@data.getChar @row, @col) != ' '
      @col += 1
    while @col < end and (@data.getChar @row, @col+1) == ' '
      @col += 1

    if @col < end or options.pastEnd
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
    if options.pastEnd
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
    row = @data.getSiblingBefore @row
    if row != @row
      @row = row
      @col = 0

  down: () ->
    row = @data.getSiblingAfter @row
    if row != @row
      @row = row
      @col = 0

# exports
module?.exports = Cursor
