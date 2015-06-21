# a View consists of Data and a cursor
# it also renders

renderLine = (lineData, onto, options = {}) ->
  options.cursors ?= {}
  options.highlights ?= {}
  defaultStyle = options.defaultStyle || ''

  # ideally this takes up space but is unselectable (uncopyable)
  cursorChar = ' '

  # array of dicts:
  # {
  #   text: text
  #   column: column
  #   cursor: true/false
  #   highlighted: true/false
  # }
  line = []

  # add cursor if at end
  if lineData.length of options.cursors
    lineData.push cursorChar

  # if still empty, put a newline
  if lineData.length == 0
    lineData.push '\n'

  for char, i in lineData
    info = {
      column: i
    }

    x = char

    if char == '\n'
      x = '<br/>'
      if i of options.cursors
        x = cursorChar + x

    if i of options.cursors
      info.cursor = true
    if i of options.highlights
      info.highlighted = true

    info.text = x
    line.push info

  # collect set of words, { word: word, start: start, end: end }
  words = []
  word = ''
  word_start = 0

  lineData.push ' ' # to make end condition easier
  for char, i in lineData
    if char == '\n' or char == ' '
      if i != word_start
        words.push {
          word: word
          start: word_start
          end: i - 1
        }
      word_start = i + 1
      word = ''
    else
      word += char

  urlRegex = /^https?:\/\/[^\s]+\.[^\s]+$/
  url_words = words.filter (w) ->
    return urlRegex.test w.word

  for url_word in url_words
    line[url_word.start].url_start = url_word.word
    line[url_word.end].url_end = url_word.word
    # console.log 'url word', url_word

  do onto.empty

  acc = ''
  style = defaultStyle
  url_onto = null

  for x in line
    mystyle = defaultStyle
    if x.cursor
      mystyle = 'cursor'
    if x.highlighted
      mystyle = 'highlight'

    if x.url_start
      if acc.length
        onto.append $('<span>').html(acc).addClass(style)
        acc = ''
      url_onto = $('<a>').attr('href', x.url_start)

    if mystyle != style
      if acc.length
        if url_onto
          url_onto.append $('<span>').html(acc).addClass(style)
        else
          onto.append $('<span>').html(acc).addClass(style)
        acc = ''
      style = mystyle

    acc += x.text

    if x.url_end
      url_onto.append $('<span>').html(acc).addClass(style)
      acc = ''

      onto.append url_onto
      url_onto = null

  if acc.length
    onto.append $('<span>').html(acc).addClass(style)

  # NOTE: the following renders each character separately
  # it makes it so we can click individual characters to move the cursor
  # however, it seems to make rendering laggy

  # for x in line
  #   mystyle = defaultStyle
  #   if x.cursor
  #     mystyle = 'cursor'
  #   if x.highlighted
  #     mystyle = 'highlight'

  #   charDiv = $('<span>').html(x.text).addClass(mystyle)
  #   if options.onclick?
  #     charDiv.on('click', options.onclick.bind @, x)
  #   onto.append charDiv

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

    row = (@data.getChildren @data.viewRoot)[0]
    @cursor = new Cursor @data, row, 0
    @register = new Register @

    @actions = [] # full action history
    @history = [{
      index: 0
    }]
    @historyIndex = 0 # index into indices

    return @

  # ACTIONS

  save: () ->
    if @history[@historyIndex].index == @actions.length
        return
    state = @history[@historyIndex]
    state.after = {
      cursor: do @cursor.clone
      viewRoot: @data.viewRoot
    }

    @historyIndex += 1
    @history.push {
      index: @actions.length
    }

  restoreViewState: (state) ->
    @cursor =  do state.cursor.clone
    @changeView state.viewRoot

  undo: () ->
    if @historyIndex > 0
      oldState = @history[@historyIndex]
      @historyIndex -= 1
      newState = @history[@historyIndex]

      for i in [(oldState.index-1)...(newState.index-1)]
          action = @actions[i]
          action.rewind @

      @restoreViewState newState.before

  redo: () ->
    if @historyIndex < @history.length - 1
      oldState = @history[@historyIndex]
      @historyIndex += 1
      newState = @history[@historyIndex]

      for i in [oldState.index...newState.index]
          action = @actions[i]
          action.reapply @
      @restoreViewState oldState.after

  act: (action) ->
    if @historyIndex + 1 != @history.length
        @history = @history.slice 0, (@historyIndex + 1)
        @actions = @actions.slice 0, @history[@historyIndex].index

    state = @history[@historyIndex]
    if @actions.length == state.index
      state.before = {
        cursor: do @cursor.clone
        viewRoot: @data.viewRoot
      }

    action.apply @
    @actions.push action

  # CURSOR MOVEMENT AND DATA MANIPULATION

  curLine: () ->
    return @data.getLine @cursor.row

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

  changeView: (row) ->
    if @data.hasChildren row
      @data.changeViewRoot row
      return true
    return false

  rootInto: (row = @cursor.row) ->
    # try changing to cursor
    if @reroot row
      return true
    parent = @data.getParent row
    if @reroot parent
      @cursor.setRow row
      return true
    throw 'Failed to root into'

  rootUp: () ->
    if @data.viewRoot != @data.root
      parent = @data.getParent @data.viewRoot
      @reroot parent

  rootDown: () ->
    newroot = @data.oldestVisibleAncestor @cursor.row
    if @reroot newroot
      return true
    return false

  reroot: (newroot = @data.root) ->
    if @changeView newroot
      newrow = @data.youngestVisibleAncestor @cursor.row
      if newrow == null # not visible, need to reset cursor
        newrow = (@data.getChildren newroot)[0]
      @cursor.setRow newrow
      return true
    return false

  addCharsAtCursor: (chars, options) ->
    @act new actions.AddChars @cursor.row, @cursor.col, chars, options

  addCharsAfterCursor: (chars, options) ->
    col = @cursor.col
    if col < (@data.getLength @cursor.row)
      col += 1
    @act new actions.AddChars @cursor.row, col, chars, options

  delChars: (row, col, nchars, options = {}) ->
    if ((@data.getLength row) > 0) and (nchars > 0)
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

  yankBetween: (cursor1, cursor2) ->
    if cursor2.row != cursor1.row
      console.log('not yet implemented')
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]
    @yankChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col)

  deleteBetween: (cursor1, cursor2, options) ->
    if cursor2.row != cursor1.row
      console.log('not yet implemented')
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]
    @delChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col), options

  newLineBelow: () ->
    children = @data.getChildren @cursor.row
    if (not @data.collapsed @cursor.row) and children.length > 0
      @act new actions.InsertRowSibling children[0], {before: true}
    else
      @act new actions.InsertRowSibling @cursor.row, {after: true}

  newLineAbove: () ->
    @act new actions.InsertRowSibling @cursor.row, {before: true}

  newLineAtCursor: () ->
    delAction = new actions.DelChars @cursor.row, 0, @cursor.col
    @act delAction
    row = @cursor.row
    sibling = @act new actions.InsertRowSibling @cursor.row, {before: true}
    @addCharsAfterCursor delAction.deletedChars, {cursor: 'beforeEnd'}
    @setCur row, 0

  joinRows: (first, second, options = {}) ->
    for child in @data.getChildren second by -1
      # NOTE: if first is collapsed, should we uncollapse?
      @moveBlock child, first, 0

    line = @data.getLine second
    if options.delimiter
      if line[0] != options.delimiter
        line = [options.delimiter].concat line
    @detachBlock second

    newCol = @data.getLength first
    action = new actions.AddChars first, newCol, line, {cursor: 'stay'}
    @act action

    @setCur first, newCol, options.cursor

  joinAtCursor: () ->
    row = @cursor.row
    sib = @data.nextVisible row
    if sib != null
      @joinRows row, sib, {cursor: 'pastEnd', delimiter: ' '}

  # implements proper "backspace" behavior
  deleteAtCursor: () ->
    if @cursor.col == 0
      row = @cursor.row
      sib = @data.prevVisible row
      if sib != null
        @joinRows sib, row, {cursor: 'pastEnd'}
    else
      @delCharsBeforeCursor 1, {cursor: 'pastEnd'}

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

  moveBlock: (row, parent, index = -1, options = {}) ->
    @detachBlock row, options
    @attachBlock row, parent, index, options

  indentBlock: (id = @cursor.row) ->
    sib = @data.getSiblingBefore id
    if sib == null
      return null # cannot indent

    if @data.collapsed sib
      @toggleBlock sib

    @moveBlock id, sib, -1
    return sib

  unindentBlock: (id = @cursor.row, options = {}) ->
    parent = @data.getParent id
    if parent == @data.viewRoot
      return null
    p_i = @data.indexOf id
    if (options.strict) and (p_i != (@data.getChildren parent).length - 1)
      return null

    newparent = @data.getParent parent
    pp_i = @data.indexOf parent

    @moveBlock id, newparent, (pp_i+1)
    return newparent

  indent: (id = @cursor.row) ->
    sib = @data.getSiblingBefore id

    newparent = @indentBlock id
    if newparent == null
      return
    for child in (@data.getChildren id).slice()
      @moveBlock child, sib, -1

  unindent: (id = @cursor.row) ->
    if @data.hasChildren id
      return

    parent = @data.getParent id
    p_i = @data.indexOf id

    newparent = @unindentBlock id
    if newparent == null
      return

    p_children = @data.getChildren parent
    for child in p_children.slice(p_i)
      @moveBlock child, id, -1

  swapDown: (row = @cursor.row) ->
    next = @data.nextVisible (@data.lastVisible row)
    if next == null
      return

    @detachBlock row
    if (@data.hasChildren next) and (not @data.collapsed next)
      # make it the first child
      @attachBlock row, next, 0
    else
      # make it the next sibling
      parent = @data.getParent next
      p_i = @data.indexOf next
      @attachBlock row, parent, (p_i+1)

  swapUp: (row = @cursor.row) ->
    prev = @data.prevVisible row
    if prev == null
      return

    @detachBlock row
    # make it the previous sibling
    parent = @data.getParent prev
    p_i = @data.indexOf prev
    @attachBlock row, parent, p_i

  toggleCurBlock: () ->
    @toggleBlock @cursor.row

  toggleBlock: (row) ->
    @act new actions.ToggleBlock row

  pasteBefore: () ->
    @register.paste {before: true}

  pasteAfter: () ->
    @register.paste {}

  find: (chars) ->
    results = @data.find chars
    return results

  scrollPages: (npages) ->
    # TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
    line_height = do $('.node-text').height
    page_height = do $(document).height
    height = npages * page_height

    numlines = Math.round(height / line_height)
    if numlines > 0
      for i in [1..numlines]
        do @cursor.down
    else
      for i in [-1..numlines]
        do @cursor.up

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

  # RENDERING

  # TODO: make the rendering do diffs (maybe data should track dirty bits)
  render: () ->
    do @mainDiv.empty

    crumbs = []
    row = @data.viewRoot
    while row != @data.root
      crumbs.push row
      row = @data.getParent row

    makeCrumb = (row, line) =>
      return $('<span>').addClass('crumb').append(
        $('<a>').html(line).click (() =>
          @reroot row
          do @save
          do @render
        )
      )

    crumbsDiv = $('<div>').attr('id', 'breadcrumbs')

    crumbsDiv.append(makeCrumb @data.root, $('<icon>').addClass('fa fa-home'))
    for row in crumbs by -1
      line = (@data.getLine row).join('')
      crumbsDiv.append(makeCrumb row, line)

    @mainDiv.append crumbsDiv

    contentDiv = $('<div>')
    @mainDiv.append contentDiv
    @renderTree @data.viewRoot, contentDiv, {ignoreCollapse: true}

    cursorDiv = $('.cursor', @mainDiv)[0]
    if cursorDiv
      @scrollIntoView cursorDiv

  renderTree: (parentid, onto, options = {}) ->
    if not onto
      onto = $('#' + (childrenDivID parentid))

    do onto.empty

    if (not options.ignoreCollapse) and (@data.collapsed parentid)
      return

    for id in @data.getChildren parentid
      el = $('<div>')
        .attr('id', containerDivID id)
        .addClass('node')

      icon = 'fa-circle'
      if @data.hasChildren id
        icon = if @data.collapsed id then 'fa-plus-circle' else 'fa-minus-circle'
      bullet = $('<i>').addClass('fa ' + icon + ' bullet')
      if @data.hasChildren id
        bullet.css({cursor: 'pointer'}).click ((id) =>
          @toggleBlock id
          do @render
        ).bind(@, id)

      elLine = $('<div>').addClass('node-text').attr('id', rowDivID id)
      @renderLine id, elLine

      children = $('<div>').addClass('node-children').attr('id', childrenDivID id)
      @renderTree id, children

      el.append(bullet).append(elLine).append(children)
      onto.append el

  renderLine: (row, onto) ->
    if not onto
      onto = $('#' + (rowDivID row))
    lineData = @data.getLine row
    cursors = {}
    if row == @cursor.row
      cursors[@cursor.col] = true

    renderLine lineData, onto, {
      cursors: cursors
      onclick: (x) =>
        @setCur row, x.column
        do @render
    }

# imports
if module?
  Cursor = require('./cursor.coffee')
  actions = require('./actions.coffee')
  Register = require('./register.coffee')

# exports
module?.exports = View
