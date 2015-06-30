class Cursor
  constructor: (data, row = null, col = null, moveCol = null) ->
    @data = data
    @row = if row == null then (@data.getChildren @data.viewRoot)[0] else row
    @col = if col == null then 0 else col

    # -1 means last col
    @moveCol = if moveCol == null then col else moveCol

  clone: () ->
    return new Cursor @data, @row, @col, @moveCol

  set: (row, col, option) ->
    @row = row
    @setCol col, option

  setRow: (row, option) ->
    @row = row
    @fromMoveCol option

  setCol: (moveCol, option = 'pastEnd') ->
    @moveCol = moveCol
    @fromMoveCol option

  fromMoveCol: (option) ->
    len = @data.getLength @row
    maxcol = len - (if option == 'pastEnd' then 0 else 1)
    if @moveCol < 0
      @col = Math.max(0, len + @moveCol + 1)
    else
      @col = Math.max(0, Math.min(maxcol, @moveCol))

  _left: () ->
    @setCol (@col - 1)

  _right: () ->
    @setCol (@col + 1)

  left: () ->
    if @col > 0
      do @_left

  right: (options = {}) ->
    shift = if options.cursor == 'pastEnd' then 0 else 1
    if @col < (@data.getLength @row) - shift
      do @_right

  # backIfNeeded: () ->
  #   if @col > (@data.getLength @row) - 1
  #     do @left

  atVisibleEnd: () ->
    if @col < (@data.getLength @row) - 1
      return false
    else
      nextrow = @data.nextVisible @row
      if nextrow != null
        return false
    return true

  nextChar: () ->
    if @col < (@data.getLength @row) - 1
      do @_right
      return true
    else
      nextrow = @data.nextVisible @row
      if nextrow != null
        @set nextrow, 0
        return true
    return false

  atVisibleStart: () ->
    if @col > 0
      return false
    else
      prevrow = @data.prevVisible @row
      if prevrow != null
        return false
    return true

  prevChar: () ->
    if @col > 0
      do @_left
      return true
    else
      prevrow = @data.prevVisible @row
      if prevrow != null
        @set prevrow, -1
        return true
    return false

  home: () ->
    @setCol 0

  end: (options = {}) ->
    @setCol (if options.cursor == 'pastEnd' then -1 else -2)

  visibleHome: () ->
    row = do @data.nextVisible
    @set row, 0

  visibleEnd: () ->
    row = do @data.lastVisible
    @set row, 0

  wordRegex = /^[a-z0-9_]+$/i

  isWhitespace = (char) ->
    return (char == ' ') or (char == undefined)

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
    if do @atVisibleStart
      return
    do @prevChar
    while (not do @atVisibleStart) and @isInWhitespace @row, @col
      do @prevChar

    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while (@col > 0) and wordcheck @row, (@col-1)
      do @_left

  endWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor == 'pastEnd'
        do @_right
      return

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @row, @col
      do @nextChar

    end = (@data.getLength @row) - 1
    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    if options.cursor == 'pastEnd'
      do @_right

  nextWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor == 'pastEnd'
        do @_right
      return

    end = (@data.getLength @row) - 1
    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @row, @col
      do @nextChar

    end = (@data.getLength @row) - 1
    if @col == end and options.cursor == 'pastEnd'
      do @_right

  findNextChar: (char, options = {}) ->
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

  findPrevChar: (char, options = {}) ->
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

  up: (options = {}) ->
    row = @data.prevVisible @row
    if row != null
      @setRow row, options.cursor

  down: (options = {}) ->
    row = @data.nextVisible @row
    if row != null
      @setRow row, options.cursor

  parent: (options = {}) ->
    row = @data.getParent @row
    if row == @data.root
      return
    if row == @data.viewRoot
      @data.changeViewRoot @data.getParent row
    @setRow row, options.cursor

  prevSibling: (options = {}) ->
    prevsib = @data.getSiblingBefore @row
    if prevsib != null
      @setRow prevsib, options.cursor

  nextSibling: (options = {}) ->
    nextsib = @data.getSiblingAfter @row
    if nextsib != null
      @setRow nextsib, options.cursor

# exports
module?.exports = Cursor
