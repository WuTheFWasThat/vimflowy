# a View consists of Data and a cursor
# it also renders

class View

  containerDivID = (id) ->
    return 'node-' + id

  rowDivID = (id) ->
    return 'node-' + id + '-row'

  childrenDivID = (id) ->
    return 'node-' + id + '-children'

  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data

    @cursor = new Cursor @data

    @actions = [] # full action history
    @history = [0] # indices into actions
    @historyIndex = 0 # index into indices

    return @

  # ACTIONS

  save: () ->
    if @history[@historyIndex] == @actions.length
        return
    @historyIndex += 1
    @history.push @actions.length

  undo: () ->
    if @historyIndex > 0
      oldIndex = @history[@historyIndex]-1
      @historyIndex -= 1
      newIndex = @history[@historyIndex]-1

      for i in [oldIndex...newIndex]
          action = @actions[i]
          action.rewind @

          # use final cursor
          [@cursor.row, @cursor.col] = action.oldCursor
          @setCur @cursor.row, @cursor.col
      do @undrawCursors
      @drawRow @cursor.row

  redo: () ->
    if @historyIndex < @history.length
      oldIndex = @history[@historyIndex]
      @historyIndex += 1
      newIndex = @history[@historyIndex]

      for i in [oldIndex...newIndex]
          action = @actions[i]
          action.apply @

      do @undrawCursors

  act: (action) ->
    if @historyIndex + 1 != @history.length
        @history = @history.slice 0, (@historyIndex + 1)
        @actions = @actions.slice 0, @history[@historyIndex]

    action.oldCursor = [@cursor.row, @cursor.col]
    action.apply @
    @actions.push action

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
    @act new actions.InsertRowSibling @cursor.row, {after: true}

  newLineAbove: () ->
    @act new actions.InsertRowSibling @cursor.row, {before: true}

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

  indentLine: () ->
    # TODO: make this undoable
    @data.indent @cursor.row
    # TODO: make this better
    do @render

  unindentLine: () ->
    # TODO: make this undoable
    @data.unindent @cursor.row
    # TODO: make this better
    do @render


  # RENDERING

  render: () ->
    @renderTree 0, @mainDiv

  undrawCursors: () ->
    $('.cursor').removeClass 'cursor'

  renderTree: (parentid, onto) ->

    do onto.empty
    for id in @data.getChildren parentid
      el = $('<div>')
        .attr('id', containerDivID id)
        .addClass('node')

      bullet = $('<i>').addClass('fa fa-circle bullet')

      elLine = $('<div>').addClass('node-text').attr('id', rowDivID id)
      @drawRow id, elLine

      children = $('<div>').addClass('node-children').attr('id', childrenDivID id)
      @renderTree id, children

      el.append(bullet).append(elLine).append(children)
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
