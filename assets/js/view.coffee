class View
  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data

    @curRow = 0 # id
    @curCol = 0

    @history = []
    @historyIndex = 0

    return @

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

  redo: () ->
    if @historyIndex < @history.length
      action = @history[@historyIndex]
      action.apply @
      @historyIndex += 1


  moveCursorBackIfNeeded: () ->
    if @curCol > data.lines[@curRow].length - 1
      do @moveCursorLeft

  moveCursorRight: (options) ->
    options?={}
    shift = if options.pastEnd then 0 else 1
    if @curCol < data.lines[@curRow].length - shift
      @curCol += 1
      @drawRow @curRow

  moveCursorLeft: () ->
    if @curCol > 0
      @curCol -= 1
      @drawRow @curRow

  act: (action) ->
    action.apply @
    @add_history action

  render: () ->
    @renderHelper @mainDiv, @data

  renderHelper: (onto, data) ->
    for child in data.structure
      do onto.empty
      id = child.id
      elId = 'node-' + id
      el = $('<div>').attr('id', elId).addClass('.node')
      elLine = $('<div>').attr 'id', (elId + '-row')

      console.log data.lines, data.lines[id]
      @drawRow id, elLine

      el.append elLine
      console.log 'elline', elLine
      console.log 'el', el
      console.log 'onto', onto
      onto.append el

  setCur: (row, col) ->
    view.curRow = row
    view.curCol = col

  drawRow: (row, onto) ->
    if not onto
      onto = $('#node-' + row + '-row')
    lineData = @data.lines[row]

    console.log lineData

    line = lineData.map (x) ->
      if x == ' '
        return '&nbsp;'
      return x

    # add cursor
    if row == @curRow and lineData.length == @curCol
      line.push '&nbsp;'

    do onto.empty

    acc = ''
    style = ''
    for x, i in line
      mystyle = ''
      if row == @curRow and i == @curCol
        mystyle = 'cursor'
      if mystyle != style
        onto.append $('<span>').html(acc).addClass(style)
        style = mystyle
        acc = ''
      acc += x

    if acc.length
      onto.append $('<span>').html(acc).addClass(style)

