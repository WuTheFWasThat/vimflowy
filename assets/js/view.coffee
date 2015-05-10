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

  redo: () ->
    if @historyIndex < @history.length - 1
      oldIndex = @history[@historyIndex]
      @historyIndex += 1
      newIndex = @history[@historyIndex]

      for i in [oldIndex...newIndex]
          action = @actions[i]
          action.apply @

  act: (action) ->
    if @historyIndex + 1 != @history.length
        @history = @history.slice 0, (@historyIndex + 1)
        @actions = @actions.slice 0, @history[@historyIndex]

    action.oldCursor = do @cursor.clone
    action.apply @
    @actions.push action

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

  moveCursorBackIfNeeded: () ->
    if @cursor.col > do @curLineLength - 1
      do @moveCursorLeft

  moveCursorLeft: () ->
    do @cursor.left

  moveCursorRight: (options) ->
    @cursor.right options

  moveCursorUp: (options = {}) ->
    oldrow = @cursor.row
    @cursor.up options

  moveCursorDown: (options = {}) ->
    oldrow = @cursor.row
    @cursor.down options

  moveCursorHome: () ->
    do @cursor.home

  moveCursorEnd: (options) ->
    @cursor.end options

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
    nchars = Math.min(@cursor.col, nchars)
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

  joinRows: (first, second, options = {}) ->
    if (@data.getChildren second).length > 0
      return

    line = @data.getLine second
    action = new actions.DeleteBlocks @cursor.row, 1, options
    @act action

    newCol = @data.getLength first
    action = new actions.AddChars first, newCol, line, {cursor: 'stay'}
    @act action

    @setCur first, newCol, options.cursor

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

  toggleCurBlock: () ->
    @toggleBlock @cursor.row

  toggleBlock: (row) ->
    @act new actions.ToggleBlock row

  pasteBefore: () ->
    @register.paste {before: true}

  pasteAfter: () ->
    @register.paste {}

  # RENDERING

  scrollPages: (npages) ->
    # TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
    line_height = do $('.node-text').height
    page_height = do $(document).height
    height = npages * page_height
    console.log('tot height', height)
    console.log('line height', line_height)

    numlines = Math.round(height / line_height)
    if numlines > 0
      for i in [1..numlines]
        do @moveCursorDown
    else
      for i in [-1..numlines]
        do @moveCursorUp

    @scrollMain (line_height * numlines)

  scrollMain: (amount) ->
     @mainDiv.stop().animate({
        scrollTop: @mainDiv[0].scrollTop + amount
     }, 100)

  scrollIntoView: (el) ->
    elemTop = el.getBoundingClientRect().top
    elemBottom = el.getBoundingClientRect().bottom

    margin = 50
    top_margin = margin
    bottom_margin = margin + $('#bottom-bar').height()

    if elemTop < top_margin
       # scroll up
       @scrollMain (elemTop - top_margin)
    else if elemBottom > window.innerHeight - bottom_margin
       # scroll down
       @scrollMain (elemBottom - window.innerHeight + bottom_margin)

  # TODO: make the rendering do diffs (maybe data should track dirty bits)
  render: () ->
    @renderTree 0, @mainDiv
    cursorDiv = $('.cursor')[0]
    if cursorDiv
      @scrollIntoView cursorDiv

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
      if (@data.getChildren id).length > 0
        bullet.css({cursor: 'pointer'}).click @toggleBlock.bind(@, id)

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
