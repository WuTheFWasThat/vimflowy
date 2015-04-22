# a View consists of Data and a cursor
# it also renders

class View
  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data

    @cursor = new Cursor @data

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

  undrawCursors: () ->
    $('.cursor').removeClass 'cursor'

  undo: () ->
    if @historyIndex > 0
      @historyIndex -= 1
      action = @history[@historyIndex]
      action.rewind @
      [@cursor.row, @cursor.col] = action.oldCursor
      @setCur @cursor.row, @cursor.col
      do @undrawCursors
      @drawRow @cursor.row

  redo: () ->
    if @historyIndex < @history.length
      do @undrawCursors
      action = @history[@historyIndex]
      action.apply @
      @historyIndex += 1

  act: (action) ->
    action.oldCursor = [@cursor.row, @cursor.col]
    action.apply @
    @add_history action

  # CURSOR MOVEMENT AND DATA MANIPULATION

  curRowLength: () ->
    return @data.rowLength @cursor.row

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

  addCharsAfterCursor: (chars, options) ->
    @act new actions.AddChars @cursor.row, @cursor.col, chars, options

  delCharsBeforeCursor: (nchars) ->
    @act new actions.DelChars @cursor.row, (@cursor.col-nchars), nchars

  delCharsAfterCursor: (nchars, options) ->
    @act new actions.DelChars @cursor.row, @cursor.col, nchars, options

  spliceCharsAfterCursor: (nchars, chars, options) ->
    @act new actions.SpliceChars @cursor.row, @cursor.col, nchars, chars, options

  newLineBelow: () ->
    # TODO: make this undoable
    row = @data.insertSiblingAfter @cursor.row
    @cursor.row = row
    @cursor.col = 0
    # TODO: make this better
    do @render

  newLineAbove: () ->
    # TODO: make this undoable
    row = @data.insertSiblingBefore @cursor.row
    @cursor.row = row
    @cursor.col = 0
    # TODO: make this better
    do @render

  delLine: () ->
    # TODO: make this undoable
    row = @data.deleteRow @cursor.row
    @cursor.row = row
    @cursor.col = 0
    # TODO: make this better
    do @render

  clearLine: () ->
    # TODO: make this undoable
    # TODO: make this better
    do @render

  # RENDERING

  render: () ->
    @renderTree 0, @mainDiv

  renderTree: (parentid, onto) ->
    do onto.empty
    for id in @data.structure[parentid].children
      elId = 'node-' + id
      el = $('<div>')
        .attr('id', elId)
        .addClass('node')

      bullet = $('<i>').addClass('fa fa-circle bullet')
      elLine = $('<div>').addClass('node-text').attr('id', (elId + '-row'))

      console.log @data.lines, id, @data.lines[id]
      @drawRow id, elLine

      el.append(bullet).append(elLine)

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

    # ideally this takes up space but is unselectable (uncopyable)
    cursorChar = '&nbsp;'

    line = []
    for char, i in lineData
      x = char

      if char == ' '
        x = '&nbsp;'
      else if char == '\n'
        x = '<br/>'
        if row == @cursor.row and i == @cursor.col
          x = cursorChar + x

      line.push x

    # add cursor if at end
    if row == @cursor.row and lineData.length == @cursor.col
      line.push cursorChar

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

# imports
if module?
  Cursor = require('./cursor.coffee')
  actions = require('./actions.coffee')

# exports
module?.exports = View
