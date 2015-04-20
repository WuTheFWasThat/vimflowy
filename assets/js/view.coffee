# a View consists of Data and a cursor
# it also renders

class Cursor
  constructor: (view, row = 1, col = 0) ->
    @view = view
    @row = row
    @col = col

  clone: () ->
    return new Cursor @view, @row, @col

  left: () ->
    if @col > 0
      @col -= 1

  right: (options) ->
    options?={}
    shift = if options.pastEnd then 0 else 1
    if @col < (@view.rowLength @row) - shift
      @col += 1

  home: () ->
    @col = 0

  end: (options) ->
    options ?= {}
    shift = if options.pastEnd then 0 else 1
    @col= (@view.rowLength @row) - shift

  beginningWord: () ->
    if @col == 0
      return
    @col -= 1
    while @col > 0 and (@view.getData @row, @col) == ' '
      @col -= 1
    while @col > 0 and (@view.getData @row, @col-1) != ' '
      @col -= 1

  endWord: (options = {}) ->
    end = (@view.rowLength @row) - 1
    if @col == end
      if options.pastEnd
        @col += 1
      return

    @col += 1
    while @col < end and (@view.getData @row, @col) == ' '
      @col += 1
    while @col < end and (@view.getData @row, @col+1) != ' '
      @col += 1

    if options.pastEnd
      @col += 1

  nextWord: (options = {}) ->
    end = (@view.rowLength @row) - 1
    if @col == end
      if options.pastEnd
        @col += 1
      return

    while @col < end and (@view.getData @row, @col) != ' '
      @col += 1
    while @col < end and (@view.getData @row, @col+1) == ' '
      @col += 1

    if @col < end or options.pastEnd
      @col += 1

class View
  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data

    @cursor = new Cursor @

    @history = []
    @historyIndex = 0

    return @

  # ACTIONS

  add_history: (action) ->
    # TODO: check if we can merge with previous action
    if @historyIndex != @history.length
        @history = @history.slice 0, @historyIndex
    @history.push action
    @historyIndex += 1

  undo: () ->
    if @historyIndex > 0
      @historyIndex -= 1
      action = @history[@historyIndex]
      action.rewind @
      [@cursor.row, @cursor.col] = action.oldCursor
      @setCur @cursor.row, @cursor.col
      @drawRow @cursor.row

  redo: () ->
    if @historyIndex < @history.length
      action = @history[@historyIndex]
      action.apply @
      @historyIndex += 1

  act: (action) ->
    action.oldCursor = [@cursor.row, @cursor.col]
    action.apply @
    @add_history action

  # CURSOR MOVEMENT AND DATA MANIPULATION

  getData: (row, col) ->
    return @data.lines[row][col]

  rowLength: (row) ->
    return @data.lines[row].length

  curRowLength: () ->
    return @rowLength @cursor.row

  setCur: (row, col, options) ->
    options ?= {}
    @cursor.row = row
    @cursor.col = col

    shift = if options.pastEnd then 0 else 1
    rowLen = do @curRowLength
    if rowLen > 0 and @cursor.col > rowLen - shift
      @cursor.col = rowLen - shift

  moveCursorBackIfNeeded: () ->
    if @cursor.col > do @curRowLength - 1
      do @moveCursorLeft


  moveCursor: (row, col) ->
    oldrow = @cursor.row
    @cursor.row = row
    @cursor.col = col

    @drawRow oldrow
    @drawRow @cursor.row

  moveCursorLeft: () ->
    do @cursor.left
    @drawRow @cursor.row

  moveCursorRight: (options) ->
    @cursor.right options
    @drawRow @cursor.row

  moveCursorHome: () ->
    do @cursor.home
    @drawRow @cursor.row

  moveCursorEnd: (options) ->
    @cursor.end options
    @drawRow @cursor.row

  # RENDERING

  render: () ->
    @renderHelper @mainDiv, 0

  renderHelper: (onto, rootid) ->
    for id in @data.structure[rootid].children
      do onto.empty
      elId = 'node-' + id
      el = $('<div>').attr('id', elId).addClass('.node')
      elLine = $('<div>').attr 'id', (elId + '-row')

      console.log @data.lines, id, @data.lines[id]
      @drawRow id, elLine

      el.append elLine
      console.log 'elline', elLine
      console.log 'el', el
      console.log 'onto', onto
      onto.append el

  drawRow: (row, onto) ->
    console.log('drawing row', row, @cursor.row, @cursor.col)
    if not onto
      onto = $('#node-' + row + '-row')
    lineData = @data.lines[row]

    console.log lineData

    line = lineData.map (x) ->
      if x == ' '
        return '&nbsp;'
      return x

    # add cursor
    if row == @cursor.row and lineData.length == @cursor.col
      line.push '&nbsp;'

    do onto.empty

    acc = ''
    style = ''
    for x, i in line
      mystyle = ''
      if row == @cursor.row and i == @cursor.col
        mystyle = 'cursor'
      if mystyle != style
        onto.append $('<span>').html(acc).addClass(style)
        style = mystyle
        acc = ''
      acc += x

    if acc.length
      onto.append $('<span>').html(acc).addClass(style)

module?.exports = View
