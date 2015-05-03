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
    @register = new Register @

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
          @cursor = action.oldCursor
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
      @drawRow @cursor.row

  act: (action) ->
    if @historyIndex + 1 != @history.length
        @history = @history.slice 0, (@historyIndex + 1)
        @actions = @actions.slice 0, @history[@historyIndex]

    action.oldCursor = do @cursor.clone
    action.apply @
    @actions.push action

  # CURSOR MOVEMENT AND DATA MANIPULATION

  curRowLength: () ->
    return @data.rowLength @cursor.row

  setCur: (row, col, option = '') ->
    if option == 'beforeEnd'
      if col > 0
        col -= 1

    shift = if option == 'pastEnd' then 0 else 1
    rowLen = do @curRowLength
    if rowLen > 0 and col > rowLen - shift
      col = rowLen - shift

    @cursor.set row, col

  setCursor: (cursor) ->
    oldrow = @cursor.row
    @cursor = cursor
    @drawRow oldrow
    @drawRow @cursor.row

  moveCursorBackIfNeeded: () ->
    if @cursor.col > do @curRowLength - 1
      do @moveCursorLeft

  moveCursorLeft: () ->
    do @cursor.left
    @drawRow @cursor.row

  moveCursorRight: (options) ->
    @cursor.right options
    @drawRow @cursor.row

  moveCursorUp: (options) ->
    oldrow = @cursor.row
    @cursor.up options

    @drawRow oldrow
    @drawRow @cursor.row

  moveCursorDown: (options) ->
    oldrow = @cursor.row
    @cursor.down options

    @drawRow oldrow
    @drawRow @cursor.row

  moveCursorHome: () ->
    do @cursor.home
    @drawRow @cursor.row

  moveCursorEnd: (options) ->
    @cursor.end options
    @drawRow @cursor.row

  addCharsAtCursor: (chars, options) ->
    @act new actions.AddChars @cursor.row, @cursor.col, chars, options

  addCharsAfterCursor: (chars, options) ->
    col = @cursor.col
    if col < (@data.rowLength @cursor.row)
      col += 1
    @act new actions.AddChars @cursor.row, col, chars, options

  delChars: (row, col, nchars, options) ->
    if (@data.rowLength row) > 0
      delAction = new actions.DelChars row, col, nchars, options
      @act delAction
      @register.saveChars delAction.deletedChars

  delCharsBeforeCursor: (nchars) ->
    @delChars @cursor.row, (@cursor.col-nchars), nchars

  delCharsAfterCursor: (nchars, options) ->
    @delChars @cursor.row, @cursor.col, nchars, options

  spliceCharsAfterCursor: (nchars, chars, options) ->
    @delCharsAfterCursor nchars, {cursor: 'pastEnd'}
    @addCharsAtCursor chars, options

  newRowBelow: () ->
    children = @data.getChildren @cursor.row
    if children.length > 0
      @act new actions.InsertRowSibling children[0], {before: true}
    else
      @act new actions.InsertRowSibling @cursor.row, {after: true}

  newRowAbove: () ->
    @act new actions.InsertRowSibling @cursor.row, {before: true}

  delRows: (nrows, options = {}) ->
    delAction = new actions.DetachRows @cursor.row, nrows, options
    @act delAction
    @register.saveRows delAction.deletedRows

  addRows: (row, rows, options = {}) ->
    @act new actions.AttachRows row, rows, options

  clearRow: () ->
    # TODO:
    do @render

  indent: (id, options = {}) ->
    sib = @data.getSiblingBefore id
    if sib == null
      return null # cannot indent

    @act new actions.DetachRows id, 1, {cursor: 'stay'}
    @act new actions.AttachRows sib, [id], -1, {cursor: 'stay'}

    if not options.recursive
      for child in (@data.getChildren id).slice()
        @act new actions.DetachRows child, 1, {cursor: 'stay'}
        @act new actions.AttachRows sib, [child], -1, {cursor: 'stay'}

  unindent: (id, options = {}) ->
    if not options.recursive
      if (@data.getChildren id).length > 0
        return

    parent = @data.getParent id
    if parent == @data.root
      return

    p_i = @data.indexOf id
    @act new actions.DetachRows id, 1, {cursor: 'stay'}

    newparent = @data.getParent parent

    pp_i = @data.indexOf parent
    @act new actions.AttachRows newparent, [id], (pp_i+1), {cursor: 'stay'}

    p_children = @data.getChildren parent
    for child in p_children.slice(p_i)
      @act new actions.DetachRows child, 1, {cursor: 'stay'}
      @act new actions.AttachRows id, [child], -1, {cursor: 'stay'}

  indentRow: () ->
    @indent @cursor.row

  unindentRow: () ->
    @unindent @cursor.row

  indentBlock: () ->
    @indent @cursor.row, {recursive: true}

  unindentBlock: () ->
    @unindent @cursor.row, {recursive: true}

  pasteBefore: () ->
    @register.paste {before: true}

  pasteAfter: () ->
    @register.paste {}

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

    # if still empty, put a newline
    if line.length == 0
      line.push '<br/>'

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
  Register = require('./register.coffee')

# exports
module?.exports = View
