class View
  constructor: (mainDiv, modeDiv, data) ->
    @mainDiv = mainDiv
    @modeDiv = modeDiv
    @data = data

    @curRow = 0 # id
    @curCol = 0

    @mode = ''
    @setMode MODES.VISUAL

    @history = []
    @historyIndex = 0

    return @

  setMode: (mode) ->
    @mode = mode
    for k, v of MODES
      if v == mode
        @modeDiv.text k
        break

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

  handleKey: (key, options) ->
    if @mode == MODES.VISUAL
      if key == 'a'
        @setMode MODES.INSERT
      else if key == 'i'
        @setMode MODES.INSERT
      else if key == 'u'
        do @undo
      else if key == ':'
        @setMode MODES.EX
      else if key == 'r'
        if options.ctrl
          do @redo
    else if @mode == MODES.INSERT
      if key == 'esc'
        @setMode MODES.VISUAL
      else
        console.log 'precur', JSON.stringify data.lines[@curRow]
        @act new AddChars @curRow, @curCol, key
        console.log 'cur', data.lines[view.curRow]

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

    # add cursor
    if row == @curRow and lineData.length == @curCol
      lineData.push ' '

    line = lineData.map (x) ->
      if x == ' '
        return '&nbsp;'
      return x

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

