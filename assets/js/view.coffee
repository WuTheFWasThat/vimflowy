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
    do @render

  redo: () ->
    if @historyIndex < @history.length - 1
      oldIndex = @history[@historyIndex]
      @historyIndex += 1
      newIndex = @history[@historyIndex]

      for i in [oldIndex...newIndex]
          action = @actions[i]
          action.apply @
      @drawRow @cursor.row
    do @render

  act: (action) ->
    if @historyIndex + 1 != @history.length
        @history = @history.slice 0, (@historyIndex + 1)
        @actions = @actions.slice 0, @history[@historyIndex]

    action.oldCursor = do @cursor.clone
    action.apply @
    @actions.push action
    do @render

  # CURSOR MOVEMENT AND DATA MANIPULATION

  curLineLength: () ->
    return @data.getLength @cursor.row

  setCur: (row, col, option = '') ->
    if option == 'beforeEnd'
      if col > 0
        col -= 1

    shift = if option == 'pastEnd' then 0 else 1
    len = @data.getLength row
    if len > 0 and col > len - shift
      col = len - shift

    @cursor.set row, col

  setCursor: (cursor) ->
    oldrow = @cursor.row
    @cursor = cursor
    @drawRow oldrow
    @drawRow @cursor.row

  moveCursorBackIfNeeded: () ->
    if @cursor.col > do @curLineLength - 1
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
    if col < (@data.getLength @cursor.row)
      col += 1
    @act new actions.AddChars @cursor.row, col, chars, options

  delChars: (row, col, nchars, options = {}) ->
    if (@data.getLength row) > 0
      delAction = new actions.DelChars row, col, nchars, options
      @act delAction
      if options.yank
        @register.saveChars delAction.deletedChars

  delCharsBeforeCursor: (nchars, options) ->
    @delChars @cursor.row, (@cursor.col-nchars), nchars, options

  delCharsAfterCursor: (nchars, options) ->
    @delChars @cursor.row, @cursor.col, nchars, options

  spliceCharsAfterCursor: (nchars, chars, options) ->
    @delCharsAfterCursor nchars, {cursor: 'pastEnd'}
    @addCharsAtCursor chars, options

  yankChars: (row, col, nchars) ->
    line = @data.getLine row
    if line.length > 0
      @register.saveChars line.slice(col, col + nchars)

  yankCharsBeforeCursor: (nchars) ->
    @yankChars @cursor.row, (@cursor.col-nchars), nchars

  yankCharsAfterCursor: (nchars) ->
    @yankChars @cursor.row, @cursor.col, nchars

  newLineBelow: () ->
    children = @data.getChildren @cursor.row
    if children.length > 0
      @act new actions.InsertRowSibling children[0], {before: true}
    else
      @act new actions.InsertRowSibling @cursor.row, {after: true}

  newLineAbove: () ->
    @act new actions.InsertRowSibling @cursor.row, {before: true}

  delBlocks: (nrows, options = {}) ->
    action = new actions.DeleteBlocks @cursor.row, nrows, options
    @act action
    @register.saveRows action.serialized_rows

  addBlocks: (serialized_rows, parent, index = -1, options = {}) ->
    action = new actions.AddBlocks serialized_rows, parent, index, options
    @act action

  yankBlocks: (nrows) ->
    siblings = @data.getSiblingRange @cursor.row, 0, (nrows-1)
    siblings = siblings.filter ((x) -> return x != null)
    serialized = siblings.map ((x) => return @data.serialize x)
    @register.saveRows serialized

  detachBlock: (row, options = {}) ->
    action = new actions.DetachBlock row, options
    @act action
    return action

  attachBlock: (row, parent, index = -1, options = {}) ->
    @act new actions.AttachBlock row, parent, index, options

  indent: (id, options = {}) ->
    sib = @data.getSiblingBefore id
    if sib == null
      return null # cannot indent

    @detachBlock id
    @attachBlock id, sib, -1

    if not options.recursive
      for child in (@data.getChildren id).slice()
        @detachBlock child
        @attachBlock child, sib, -1

  unindent: (id, options = {}) ->
    if not options.recursive
      if (@data.getChildren id).length > 0
        return

    parent = @data.getParent id
    if parent == @data.root
      return
    p_i = @data.indexOf id

    newparent = @data.getParent parent
    pp_i = @data.indexOf parent

    @detachBlock id
    @attachBlock id, newparent, (pp_i+1)

    p_children = @data.getChildren parent
    for child in p_children.slice(p_i)
      @detachBlock child, {cursor: 'stay'}
      @attachBlock child, id, -1, {cursor: 'stay'}

  indentLine: () ->
    @indent @cursor.row

  unindentLine: () ->
    @unindent @cursor.row

  indentBlock: () ->
    @indent @cursor.row, {recursive: true}

  unindentBlock: () ->
    @unindent @cursor.row, {recursive: true}

  toggleBlock: () ->
    @act new actions.ToggleBlock @cursor.row

  pasteBefore: () ->
    @register.paste {before: true}

  pasteAfter: () ->
    @register.paste {}

  # RENDERING

  # TODO: make the rendering do diffs (maybe data should track dirty bits)
  render: () ->
    @renderTree 0, @mainDiv

  renderTree: (parentid, onto) ->
    if not onto
      onto = $('#' + (childrenDivID parentid))

    do onto.empty

    if @data.collapsed parentid
      return

    for id in @data.getChildren parentid
      el = $('<div>')
        .attr('id', containerDivID id)
        .addClass('node')

      icon = 'fa-circle'
      if (@data.getChildren id).length > 0
        icon = if @data.collapsed id then 'fa-plus-circle' else 'fa-minus-circle'
      bullet = $('<i>').addClass('fa ' + icon + ' bullet')

      elLine = $('<div>').addClass('node-text').attr('id', rowDivID id)
      @drawRow id, elLine

      children = $('<div>').addClass('node-children').attr('id', childrenDivID id)
      @renderTree id, children

      el.append(bullet).append(elLine).append(children)
      onto.append el

  drawRow: (row, onto) ->
    if not onto
      onto = $('#' + (rowDivID row))
    lineData = @data.lines[row]

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
