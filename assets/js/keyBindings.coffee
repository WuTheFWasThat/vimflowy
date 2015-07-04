# binds keys to manipulation of view/data

# imports
if module?
  EventEmitter = require('./eventEmitter.coffee')
  Cursor = require('./cursor.coffee')
  Menu = require('./menu.coffee')
  actions = require('./actions.coffee')
  _ = require('underscore')

MODES =
  NORMAL: 0
  INSERT: 1
  VISUAL: 2
  MENU: 3

defaultVimKeyBindings = {}

defaultVimKeyBindings[MODES.NORMAL] =
  'HELP'              : ['?']
  'INSERT'            : ['i']
  'INSERT_HOME'       : ['I']
  'INSERT_AFTER'      : ['a']
  'INSERT_END'        : ['A']
  'INSERT_LINE_BELOW' : ['o']
  'INSERT_LINE_ABOVE' : ['O']

  'REPLACE'           : ['r']
  'UNDO'              : ['u']
  'REDO'              : ['ctrl+r']
  'REPLAY'            : ['.']

  'LEFT'              : ['h', 'left']
  'RIGHT'             : ['l', 'right']
  'UP'                : ['k', 'up']
  'DOWN'              : ['j', 'down']
  'HOME'              : ['0', '^']
  'END'               : ['$']
  'BEGINNING_WORD'    : ['b']
  'END_WORD'          : ['e']
  'NEXT_WORD'         : ['w']
  'BEGINNING_WWORD'   : ['B']
  'END_WWORD'         : ['E']
  'NEXT_WWORD'        : ['W']
  'FIND_NEXT_CHAR'    : ['f']
  'FIND_PREV_CHAR'    : ['F']
  'TO_NEXT_CHAR'      : ['t']
  'TO_PREV_CHAR'      : ['T']

  'GO'                : ['g']
  'PARENT'            : ['p']
  'GO_END'            : ['G']
  'DELETE'            : ['d']
  'CHANGE'            : ['c']
  'DELETE_CHAR'       : ['x']
  'DELETE_LAST_CHAR'  : ['X']
  'CHANGE_CHAR'       : ['s']
  'YANK'              : ['y']
  'PASTE_AFTER'       : ['p']
  'PASTE_BEFORE'      : ['P']
  'JOIN_LINE'         : ['J']

  'INDENT_RIGHT'      : ['tab']
  'INDENT_LEFT'       : ['shift+tab']
  'MOVE_BLOCK_RIGHT'  : ['>', 'ctrl+l']
  'MOVE_BLOCK_LEFT'   : ['<', 'ctrl+h']
  'MOVE_BLOCK_DOWN'   : ['ctrl+j']
  'MOVE_BLOCK_UP'     : ['ctrl+k']

  'NEXT_SIBLING'      : ['alt+j']
  'PREV_SIBLING'      : ['alt+k']

  'TOGGLE_FOLD'       : ['z']
  'ZOOM_IN'           : ['shift+enter', ']', 'alt+l', 'ctrl+right']
  'ZOOM_OUT'          : ['enter', '[', 'alt+h', 'ctrl+left']
  'ZOOM_OUT_ALL'      : ['{']
  'ZOOM_IN_ALL'       : ['}']
  'SCROLL_DOWN'       : ['ctrl+d']
  'SCROLL_UP'         : ['ctrl+u']

  'SEARCH'            : ['/', 'ctrl+f']
  'RECORD_MACRO'      : ['q']
  'PLAY_MACRO'        : ['@']

  'ENTER_VISUAL'      : ['v']

  'EXPORT'            : ['ctrl+s']

defaultVimKeyBindings[MODES.INSERT] =
  'LEFT'              : ['left']
  'RIGHT'             : ['right']
  'UP'                : ['up']
  'DOWN'              : ['down']
  'HOME'              : ['ctrl+a', 'home']
  'END'               : ['ctrl+e', 'end']
  'BEGINNING_WORD'    : ['alt+b']
  'END_WORD'          : ['alt+f']
  'NEXT_WORD'         : []
  'BEGINNING_WWORD'   : []
  'END_WWORD'         : []
  'NEXT_WWORD'        : []
  'FIND_NEXT_CHAR'    : []
  'FIND_PREV_CHAR'    : []
  'TO_NEXT_CHAR'      : []
  'TO_PREV_CHAR'      : []

  'BACKSPACE'         : ['backspace']
  'DELKEY'            : ['shift+backspace']
  'SPLIT'             : ['enter']

  'INDENT_RIGHT'      : ['tab']
  'INDENT_LEFT'       : ['shift+tab']
  'MOVE_BLOCK_RIGHT'  : []
  'MOVE_BLOCK_LEFT'   : []
  'MOVE_BLOCK_DOWN'   : []
  'MOVE_BLOCK_UP'     : []

  'NEXT_SIBLING'      : []
  'PREV_SIBLING'      : []

  'TOGGLE_FOLD'       : ['ctrl+z']
  'ZOOM_OUT'          : ['ctrl+left']
  'ZOOM_IN'           : ['ctrl+right']
  'ZOOM_OUT_ALL'      : ['ctrl+shift+left']
  'ZOOM_IN_ALL'       : ['ctrl+shift+right']
  'SCROLL_DOWN'       : ['ctrl+d']
  'SCROLL_UP'         : ['ctrl+u']

  'SEARCH'            : []
  'EXPORT'            : ['ctrl+s']
  'EXIT_MODE'         : ['esc', 'ctrl+c']

defaultVimKeyBindings[MODES.VISUAL] =
  'YANK'              : ['y']
  'DELETE'            : ['d', 'x']
  'CHANGE'            : ['c']
  'SWAP_CURSOR'       : ['o', 'O']
  'EXIT_MODE'         : ['esc', 'ctrl+c']
  # 'REPLACE'           : ['r']
  # 'SWAP_CASE'         : ['~']

# defaultVimKeyBindings[MODES.VISUAL_LINE] =
#   'INDENT_RIGHT'      : ['>']
#   'INDENT_LEFT'       : ['<']
#   'YANK'              : ['y']
#   'DELETE'            : ['d']
#   'CHANGE'            : ['c']
#   'REPLACE'           : ['r']

defaultVimKeyBindings[MODES.MENU] =
  'MENU_SELECT'       : ['enter']
  'MENU_UP'           : ['ctrl+k', 'up', 'tab']
  'MENU_DOWN'         : ['ctrl+j', 'down', 'shift+tab']

  'LEFT'              : ['left']
  'RIGHT'             : ['right']
  'HOME'              : ['ctrl+a', 'home']
  'END'               : ['ctrl+e', 'end']
  'BEGINNING_WORD'    : ['alt+b']
  'END_WORD'          : ['alt+f']
  'NEXT_WORD'         : []
  'BEGINNING_WWORD'   : []
  'END_WWORD'         : []
  'NEXT_WWORD'        : []
  'FIND_NEXT_CHAR'    : []
  'FIND_PREV_CHAR'    : []
  'TO_NEXT_CHAR'      : []
  'TO_PREV_CHAR'      : []

  'BACKSPACE'         : ['backspace']
  'DELKEY'            : ['shift+backspace']

  'EXIT_MODE'         : ['esc', 'ctrl+c']

# display:
#   is displayed in keybindings help screen
#
# each should have 1 of the following four
# fn:
#   takes a view and mutates it
#   if this is a motion, takes an extra cursor argument first
# continue:
#   a function which takes next key
# bindings:
#   a dictionary from keyDefinitions to functions
#   *SPECIAL KEYS*
#   if the key is 'MOTION', the function takes a cursor # TODO: make that less janky
# motion:
#   if the binding is a motion
# to_mode:
#   mode to switch to
keyDefinitions =
  HELP:
    display: 'Show/hide key bindings'
    drop: true
    fn: () ->
      @keybindingsDiv.toggleClass 'active'
      if localStorage?
        localStorage['showKeyBindings'] = @keybindingsDiv.hasClass 'active'
      do @buildBindingsDiv

  ZOOM_IN:
    display: 'Zoom in by one level'
    fn: () ->
      do @view.rootDown
  ZOOM_OUT:
    display: 'Zoom out by one level'
    fn: () ->
      do @view.rootUp
  ZOOM_IN_ALL:
    display: 'Zoom in onto cursor'
    fn: () ->
      do @view.rootInto
  ZOOM_OUT_ALL:
    display: 'Zoom out to home'
    fn: () ->
      do @view.reroot

  INDENT_RIGHT:
    display: 'Indent row right'
    fn: () ->
      do @view.indent
  INDENT_LEFT:
    display: 'Indent row left'
    fn: () ->
      do @view.unindent
  MOVE_BLOCK_RIGHT:
    display: 'Move block right'
    fn: () ->
      do @view.indentBlock
  MOVE_BLOCK_LEFT:
    display: 'Move block left'
    fn: () ->
      do @view.unindentBlock
  MOVE_BLOCK_DOWN:
    display: 'Move block down'
    fn: () ->
      do @view.swapDown
  MOVE_BLOCK_UP:
    display: 'Move block up'
    fn: () ->
      do @view.swapUp

  TOGGLE_FOLD:
    display: 'Toggle whether a block is folded'
    fn: () ->
      do @view.toggleCurBlock

  # content-based navigation

  SEARCH:
    display: 'Search'
    drop: true
    menu: (view, text) ->
      # a list of {contents, highlights, fn}
      # SEE: menu.coffee
      results = []

      selectRow = (row) ->
        view.rootInto row

      for found in view.find text
        row = found.row
        index = found.index

        highlights = {}
        for i in [index ... index + text.length]
          highlights[i] = true

        results.push {
          contents: view.data.getLine row
          highlights: highlights
          fn: selectRow.bind(@, row)
        }
      return results

  # traditional vim stuff
  INSERT:
    display: 'Insert at character'
    to_mode: MODES.INSERT
    fn: () -> return
  INSERT_AFTER:
    display: 'Insert after character'
    to_mode: MODES.INSERT
    fn: () ->
      @view.cursor.right {cursor: 'pastEnd'}
  INSERT_HOME:
    display: 'Insert at beginning of line'
    to_mode: MODES.INSERT
    fn: () ->
      do @view.cursor.home
  INSERT_END:
    display: 'Insert after end of line'
    to_mode: MODES.INSERT
    fn: () ->
      @view.cursor.end {cursor: 'pastEnd'}
  INSERT_LINE_BELOW:
    display: 'Insert on new line after current line'
    to_mode: MODES.INSERT
    fn: () ->
      do @view.newLineBelow
  INSERT_LINE_ABOVE:
    display: 'Insert on new line before current line'
    to_mode: MODES.INSERT
    fn: () ->
      do @view.newLineAbove
  REPLACE:
    display: 'Replace character'
    continue: (char) ->
      num = Math.min(@repeat, do @view.curLineLength - @view.cursor.col)
      newChars = (char for i in [1..num])
      @view.spliceCharsAfterCursor num, newChars, {cursor: 'beforeEnd'}

  UNDO:
    display: 'Undo'
    drop: true
    fn: () ->
      for i in [1..@repeat]
        do @view.undo
  REDO:
    display: 'Redo'
    drop: true
    fn: () ->
      for i in [1..@repeat]
        do @view.redo
  REPLAY:
    display: 'Replay last command'

  LEFT:
    display: 'Move cursor left'
    motion: true
    fn: (cursor, option) ->
      cursor.left {cursor: option}
  RIGHT:
    display: 'Move cursor right'
    motion: true
    fn: (cursor, option) ->
      cursor.right {cursor: option}
  UP:
    display: 'Move cursor up'
    motion: true
    fn: (cursor, option) ->
      cursor.up {cursor: option}
  DOWN:
    display: 'Move cursor down'
    motion: true
    fn: (cursor, option) ->
      cursor.down {cursor: option}
  HOME:
    display: 'Move cursor to beginning of line'
    motion: true
    fn: (cursor, option) ->
      cursor.home {cursor: option}
  END:
    display: 'Move cursor to end of line'
    motion: true
    fn: (cursor, option) ->
      cursor.end {cursor: option}
  BEGINNING_WORD:
    display: 'Move cursor to the first word-beginning before it'
    motion: true
    fn: (cursor, option) ->
      cursor.beginningWord {cursor: option}
  END_WORD:
    display: 'Move cursor to the first word-ending after it'
    motion: true
    fn: (cursor, option) ->
      cursor.endWord {cursor: option}
  NEXT_WORD:
    display: 'Move cursor to the beginning of the next word'
    motion: true
    fn: (cursor, option) ->
      cursor.nextWord {cursor: option}
  BEGINNING_WWORD:
    display: 'Move cursor to the first Word-beginning before it'
    motion: true
    fn: (cursor, option) ->
      cursor.beginningWord {cursor: option, whitespaceWord: true}
  END_WWORD:
    display: 'Move cursor to the first Word-ending after it'
    motion: true
    fn: (cursor, option) ->
      cursor.endWord {cursor: option, whitespaceWord: true}
  NEXT_WWORD:
    display: 'Move cursor to the beginning of the next Word'
    motion: true
    fn: (cursor, option) ->
      cursor.nextWord {cursor: option, whitespaceWord: true}
  FIND_NEXT_CHAR:
    display: 'Move cursor to next occurrence of character in line'
    motion: true
    continue: (char, cursor, option) ->
      cursor.findNextChar char, {cursor: option}
  FIND_PREV_CHAR:
    display: 'Move cursor to previous occurrence of character in line'
    motion: true
    continue: (char, cursor, option) ->
      cursor.findPrevChar char, {cursor: option}
  TO_NEXT_CHAR:
    display: 'Move cursor to just before next occurrence of character in line'
    motion: true
    continue: (char, cursor, option) ->
      cursor.findNextChar char, {cursor: option, beforeFound: true}
  TO_PREV_CHAR:
    display: 'Move cursor to just after previous occurrence of character in line'
    motion: true
    continue: (char, cursor, option) ->
      cursor.findPrevChar char, {cursor: option, beforeFound: true}

  NEXT_SIBLING:
    display: 'Move cursor to the next sibling of the current line'
    motion: true
    fn: (cursor, option) ->
      cursor.nextSibling {cursor: option}

  PREV_SIBLING:
    display: 'Move cursor to the previous sibling of the current line'
    motion: true
    fn: (cursor, option) ->
      cursor.prevSibling {cursor: option}

  GO:
    display: 'Various commands for navigation (operator)'
    motion: true
    bindings:
      GO:
        display: 'Go to the beginning of visible document'
        motion: true
        fn: (cursor, option) ->
          do cursor.visibleHome
      PARENT:
        display: 'Go to the parent of current line'
        motion: true
        fn: (cursor, option) ->
          do cursor.parent
  GO_END:
    display: 'Go to end of visible document'
    motion: true
    fn: (cursor, option) ->
      do cursor.visibleEnd
  DELETE_CHAR:
    display: 'Delete character'
    fn: () ->
      @view.delCharsAfterCursor @repeat, {yank: true}
  DELETE_LAST_CHAR:
    display: 'Delete last character'
    fn: () ->
      num = Math.min @view.cursor.col, @repeat
      if num > 0
        @view.delCharsBeforeCursor num, {yank: true}
  CHANGE_CHAR:
    display: 'Change character'
    to_mode: MODES.INSERT
    fn: () ->
      @view.delCharsAfterCursor 1, {cursor: 'pastEnd'}, {yank: true}
  DELETE:
    display: 'Delete (operator)'
    bindings:
      DELETE:
        display: 'Delete blocks'
        fn: () ->
          @view.delBlocks @repeat, {addNew: false}
      MOTION:
        display: 'Delete from cursor with motion'
        fn: (cursor, options = {}) ->
          options.yank = true
          @view.deleteBetween @view.cursor, cursor, options
  CHANGE:
    display: 'Change (operator)'
    bindings:
      CHANGE:
        display: 'Delete blocks, and enter insert mode'
        to_mode: MODES.INSERT
        fn: () ->
          @view.delBlocks @repeat, {addNew: true}
      MOTION:
        display: 'Delete from cursor with motion, and enter insert mode'
        to_mode: MODES.INSERT
        fn: (cursor, options = {}) ->
          options.yank = true
          options.cursor = 'pastEnd'
          @view.deleteBetween @view.cursor, cursor, options

  YANK:
    display: 'Yank (operator)'
    bindings:
      YANK:
        display: 'Yank blocks'
        drop: true
        fn: () ->
          @view.yankBlocks @repeat
      MOTION:
        display: 'Yank from cursor with motion'
        drop: true
        fn: (cursor, options = {}) ->
          @view.yankBetween @view.cursor, cursor, options
  PASTE_AFTER:
    display: 'Paste after cursor'
    fn: () ->
      do @view.pasteAfter
  PASTE_BEFORE:
    display: 'Paste before cursor'
    fn: () ->
      do @view.pasteBefore

  JOIN_LINE:
    display: 'Join current line with line below'
    fn: () ->
      do @view.joinAtCursor

  SCROLL_DOWN:
    display: 'Scroll half window down'
    drop: true
    fn: () ->
      @view.scrollPages 0.5
  SCROLL_UP:
    display: 'Scroll half window up'
    drop: true
    fn: () ->
      @view.scrollPages -0.5
  EXPORT:
    display: 'Save a file'
    fn: () ->
      do @view.data.export
  RECORD_MACRO:
    display: 'Begin/stop recording a macro'
  PLAY_MACRO:
    display: 'Play a macro'

  # for everything but normal mode
  EXIT_MODE:
    display: 'Exit back to normal mode'
    to_mode: MODES.NORMAL
    fn: () -> return

  # for visual mode
  ENTER_VISUAL:
    display: 'Enter visual mode'
    to_mode: MODES.VISUAL
    fn: () ->
      @view.anchor = do @view.cursor.clone
  SWAP_CURSOR:
    display: 'Swap cursor to other end of selection, in visual mode'
    fn: () ->
      tmp = @view.anchor
      @view.anchor = @view.cursor
      @view.cursor = tmp

  # for insert mode

  BACKSPACE:
    display: 'Delete a character before the cursor (i.e. backspace key)'
    fn: () ->
      do @view.deleteAtCursor
  DELKEY:
    display: 'Delete a character after the cursor (i.e. del key)'
    fn: () ->
      @view.delCharsAfterCursor 1
  SPLIT:
    display: 'Split line at cursor (i.e. enter key)'
    fn: () ->
      do @view.newLineAtCursor

  # for menu mode
  MENU_SELECT:
    display: 'Select current menu selection'
    to_mode: MODES.NORMAL
    fn: () ->
      do @menu.select
      do @view.save # b/c could've zoomed
  MENU_UP:
    display: 'Select previous menu selection'
    fn: () ->
      console.log('menu up')
      do @menu.up
  MENU_DOWN:
    display: 'Select next menu selection'
    fn: () ->
      console.log('menu down')
      do @menu.down

# end of keyDefinitions

# manages a stream of keys, with the ability to
# - queue keys
# - wait for more keys
# - flush sequences of keys
# - save sequences of relevant keys
class KeyStream extends EventEmitter
  constructor: (keys = []) ->
    super

    @queue = [] # queue so that we can read group of keys, like 123 or fy
    @lastSequence = [] # last key sequence
    @index = 0
    @waiting = false

    for key in keys
      @enqueue key

  empty: () ->
    return @queue.length == 0

  done: () ->
    return @index == @queue.length

  rewind: () ->
    @index = 0

  enqueue: (key) ->
    @queue.push key
    @waiting = false

  dequeue: () ->
    if @index == @queue.length then return null
    return @queue[@index++]

  # means we are waiting for another key before we can do things
  wait: () ->
    @waiting = true
    do @rewind

  save: () ->
    processed = do @forget
    @lastSequence = processed
    @emit 'save'

  forget: () ->
    dropped = @queue.splice 0, @index
    @index = 0
    return dropped

class KeyBindings

  # takes keyDefinitions and keyMaps, and combines them
  getBindings = (definitions, keyMap) ->
    bindings = {}
    for name, v of definitions
      if name == 'MOTION'
        keys = ['MOTION']
      else if (name of keyMap)
        keys = keyMap[name]
      else
        # throw "Error:  keyMap missing key for #{name}"
        continue

      v = _.clone v
      v.name = name
      if v.bindings
        v.bindings = getBindings v.bindings, keyMap

      for key in keys
        if key of bindings
          throw "Error:  Duplicate binding on key #{key}"
        bindings[key] = v
    return bindings

  constructor: (view, options = {}) ->
    @view = view

    @keyMaps = JSON.parse JSON.stringify defaultVimKeyBindings

    @bindings = {}
    @bindings[MODES.NORMAL] = getBindings keyDefinitions, @keyMaps[MODES.NORMAL]
    @bindings[MODES.VISUAL] = getBindings keyDefinitions, @keyMaps[MODES.VISUAL]
    @bindings[MODES.INSERT] = getBindings keyDefinitions, @keyMaps[MODES.INSERT]
    @bindings[MODES.MENU]   = getBindings keyDefinitions, @keyMaps[MODES.MENU]

    if options.keyBindingsDiv
      @keybindingsDiv = options.keyBindingsDiv

    if options.menuDiv
      @menuDiv = options.menuDiv

    if options.modeDiv
      @modeDiv = options.modeDiv

    @mode = null
    @setMode MODES.NORMAL

    @macros = {}
    @recording = null
    @recording_key = null

    @keyStream = new KeyStream
    @keyStream.on 'save', () =>
      do @view.save

  buildBindingsDiv: () ->
    if not (localStorage? and localStorage['showKeyBindings'])
      return

    modeKeymap = @keyMaps[@mode] || {}

    table = $('<table>')

    buildTableContents = (definitions, onto) =>
      for k,v of definitions
        if k == 'MOTION'
          keys = ['<MOTION>']
        else
          keys = modeKeymap[k]
          if not keys
            continue

        if keys.length == 0
          continue

        row = $('<tr>')

        # row.append $('<td>').text keys[0]
        row.append $('<td>').text keys.join(' OR ')

        display_cell = $('<td>').css('width', '100%').text v.display
        if v.bindings
          buildTableContents v.bindings, display_cell
        row.append display_cell

        onto.append row

    buildTableContents keyDefinitions, table
    @keybindingsDiv.empty().append(table)

  setMode: (mode) ->
    @mode = mode
    if @modeDiv
      for k, v of MODES
        if v == mode
          @modeDiv.text k
          break
    if @menuDiv
      @menuDiv.toggleClass 'hidden', (mode != MODES.MENU)
    if @keybindingsDiv
      @keybindingsDiv.toggleClass 'hidden', (mode == MODES.MENU)
    if @view.mainDiv
      @view.mainDiv.toggleClass 'hidden', (mode == MODES.MENU)
    do @buildBindingsDiv

  handleKey: (key) ->
    console.log('handling', key)
    @keyStream.enqueue key
    if @recording
      @recording.enqueue key
    @processKeys @keyStream

  processKeys: (keyStream) ->
    while not keyStream.done() and not keyStream.waiting
      @processOnce keyStream
    do @view.render

  processOnce: (keyStream) ->
    if @mode == MODES.NORMAL
      @processNormalMode keyStream
    else if @mode == MODES.INSERT
      @processInsertMode keyStream
    else if @mode == MODES.VISUAL
      @processVisualMode keyStream
    else if @mode == MODES.MENU
      @processMenuMode keyStream

  processInsertMode: (keyStream) ->
    key = do keyStream.dequeue
    if key == null then throw 'Got no key in insert mode'
    # if key == null then return do keyStream.wait

    bindings = @bindings[MODES.INSERT]

    if not (key of bindings)
      if key == 'shift+enter'
        key = '\n'
      @view.addCharsAtCursor [key], {cursor: 'pastEnd'}
      return

    info = bindings[key]

    if info.motion
      motion = info.fn
      motion @view.cursor, 'pastEnd'
    else if info.fn
      fn = info.fn
      args = []
      context = {
        view: @view,
        repeat: 1,
        setMode: @setMode
      }
      fn.apply context, args

    if info.to_mode == MODES.NORMAL
      do @view.cursor.left
      @setMode MODES.NORMAL
      return do keyStream.save

  processVisualMode: (keyStream) ->
    key = do keyStream.dequeue
    if key == null then throw 'Got no key in visual mode'
    # if key == null then return do keyStream.wait

    bindings = @bindings[MODES.VISUAL]

    if not (key of bindings)
      [motion, repeat] = @getMotion keyStream, key
      if motion != null

        tmp = do @view.cursor.clone # this is necessary until we figure out multiline

        for i in [1..repeat]
          motion tmp, 'pastEnd'

        if tmp.row == @view.cursor.row # only allow same-row movement
          @view.cursor = tmp
      return

    info = bindings[key]

    args = []
    to_normal = false
    context = {
      view: @view,
      repeat: 1,
      setMode: @setMode
    }

    if info.bindings
      # TODO: all of this is a terrible hack...
      info = info.bindings['MOTION']
      fn = info.fn
      args.push @view.anchor, {includeEnd: true}

      to_mode = MODES.NORMAL
    else
      fn = info.fn

    if info.to_mode?
      to_mode = info.to_mode
    else
      to_mode = null

    fn.apply context, args

    if to_mode != null
      @view.anchor = null
      @setMode to_mode
      if to_mode == MODES.NORMAL
        do @view.cursor.backIfNeeded
      return do keyStream.save

    return do keyStream.forget

  processMenuMode: (keyStream) ->
    key = do keyStream.dequeue
    if key == null then throw 'Got no key in menu mode'

    bindings = @bindings[MODES.MENU]

    view = @menu.view

    if not (key of bindings)
      if key == 'shift+enter'
        key = '\n'
      view.addCharsAtCursor [key], {cursor: 'pastEnd'}
    else
      info = bindings[key]

      if info.motion
        motion = info.fn
        motion view.cursor, 'pastEnd'
      else if info.fn
        fn = info.fn
        args = []
        context = {
          view: view,
          menu: @menu
          repeat: 1,
          setMode: @setMode
        }
        fn.apply context, args

      if info.to_mode == MODES.NORMAL
        @setMode MODES.NORMAL

    do @menu.update
    do @menu.render
    return do keyStream.forget

  # takes keyStream, key, returns repeat number and key
  getRepeat: (keyStream, key = null) ->
    if key == null
      key = do keyStream.dequeue
    begins = [1..9].map ((x) -> return do x.toString)
    continues = [0..9].map ((x) -> return do x.toString)
    if key not in begins
      return [1, key]
    numStr = key
    key = do keyStream.dequeue
    if key == null then return [null, null]
    while key in continues
      numStr += key
      key = do keyStream.dequeue
      if key == null then return [null, null]
    return [parseInt(numStr), key]

  # useful when you expect a motion
  getMotion: (keyStream, motionKey, bindings = @bindings[MODES.NORMAL], repeat = 1) =>
    [motionRepeat, motionKey] = @getRepeat keyStream, motionKey
    repeat = repeat * motionRepeat

    if motionKey == null
      do keyStream.wait
      return [null, repeat]

    info = bindings[motionKey] || {}
    if not info.motion
      do keyStream.forget
      return [null, repeat]

    fn = null

    if info.continue
      key = do keyStream.dequeue
      if key == null
        do keyStream.wait
        return [null, repeat]
      fn = info.continue.bind @, key

    else if info.bindings
      answer = (@getMotion keyStream, null, info.bindings, repeat)
      return answer
    else if info.fn
      fn = info.fn

    return [fn, repeat]


  processNormalMode: (keyStream, bindings = @bindings[MODES.NORMAL], repeat = 1) ->
    [newrepeat, key] = @getRepeat keyStream
    if key == null then return do keyStream.wait
    # TODO: something better for passing repeat through?
    repeat = repeat * newrepeat

    fn = null
    args = []

    if not (key of bindings)
      if 'MOTION' of bindings
        info = bindings['MOTION']

        # note: this uses original bindings to determine what's a motion
        [motion, repeat] = @getMotion keyStream, key, @bindings[MODES.NORMAL], repeat
        if motion == null then return do keyStream.forget

        cursor = do @view.cursor.clone
        for i in [1..repeat]
          motion cursor, 'pastEnd'

        args.push cursor
      else
        return do keyStream.forget
    else
      info = bindings[key] || {}

    if info.bindings
      return @processNormalMode keyStream, info.bindings, repeat

    if info.motion
      # note: this uses *new* bindings to determine what's a motion
      [motion, repeat] = @getMotion keyStream, key, bindings, repeat
      if motion == null then return

      for j in [1..repeat]
        motion @view.cursor, ''
      return do keyStream.forget

    if info.menu
      @setMode MODES.MENU
      @menu = new Menu @menuDiv, (info.menu.bind @, @view)
      do @menu.render
      return do keyStream.forget

    if info.continue
      key = do keyStream.dequeue
      if key == null then return do keyStream.wait

      fn = info.continue
      args.push key
    else if info.fn
      fn = info.fn

    if fn
      context = {
        view: @view,
        repeat: repeat,
        keybindingsDiv: @keybindingsDiv,
        buildBindingsDiv: @buildBindingsDiv,
        keyMaps: @keyMaps,
        mode: @mode,
        setMode: @setMode
      }
      fn.apply context, args

      if info.to_mode
        @setMode info.to_mode
        if info.to_mode == MODES.INSERT
          return
        else
          return do keyStream.forget
      if info.drop
        return do keyStream.forget
      else
        return do keyStream.save

    if info.name == 'RECORD_MACRO'
      if @recording == null
        nkey = do keyStream.dequeue
        if nkey == null then return do keyStream.wait
        @recording = new KeyStream
        @recording_key = nkey
      else
        macro = @recording.queue
        do macro.pop # pop off the RECORD_MACRO itself
        @macros[@recording_key] = macro
        @recording = null
        @recording_key = null
      return do keyStream.forget
    if info.name == 'PLAY_MACRO'
        nkey = do keyStream.dequeue
        if nkey == null then return do keyStream.wait
        recording = @macros[nkey]
        if recording == undefined then return do keyStream.forget

        for i in [1..repeat]
          # the recording shouldn't save, (i.e. no @view.save)
          recordKeyStream = new KeyStream recording
          @processKeys recordKeyStream
        # but we should save the macro-playing sequence itself
        return do keyStream.save

    if info.name == 'REPLAY'
      for i in [1..repeat]
        newStream = new KeyStream @keyStream.lastSequence
        newStream.on 'save', () =>
          do @view.save
        @processKeys newStream
      return do keyStream.forget
    else
      return do keyStream.forget

# exports
module?.exports = KeyBindings
