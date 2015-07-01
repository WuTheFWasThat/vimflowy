# binds keys to manipulation of view/data

# imports
if module?
  EventEmitter = require('./eventEmitter.coffee')
  Cursor = require('./cursor.coffee')
  Menu = require('./menu.coffee')
  actions = require('./actions.coffee')
  _ = require('underscore')

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
keyDefinitions =
  HELP:
    display: 'Show/hide key bindings'
    drop: true
    fn: () ->
      @keybindingsDiv.toggleClass 'active'
      if localStorage?
        localStorage['showKeyBindings'] = @keybindingsDiv.hasClass 'active'

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
    insert: true
    fn: () -> return
  INSERT_AFTER:
    display: 'Insert after character'
    insert: true
    fn: () ->
      @view.cursor.right {cursor: 'pastEnd'}
  INSERT_HOME:
    display: 'Insert at beginning of line'
    insert: true
    fn: () ->
      do @view.cursor.home
  INSERT_END:
    display: 'Insert after end of line'
    insert: true
    fn: () ->
      @view.cursor.end {cursor: 'pastEnd'}
  INSERT_LINE_BELOW:
    display: 'Insert on new line after current line'
    insert: true
    fn: () ->
      do @view.newLineBelow
  INSERT_LINE_ABOVE:
    display: 'Insert on new line before current line'
    insert: true
    fn: () ->
      do @view.newLineAbove
  REPLACE:
    display: 'Replace character'
    continue: (char) ->
      num = Math.min(@repeat, do @view.curLineLength - @view.cursor.col)
      newChars = (char for i in [1..num])
      @view.spliceCharsAfterCursor num, newChars, {cursor: 'beforeEnd'}

  # EX:
  #   display: 'Enter EX mode'

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
    insert: true
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
        fn: (cursor) ->
          @view.deleteBetween @view.cursor, cursor, {yank: true}
  CHANGE:
    display: 'Change (operator)'
    bindings:
      CHANGE:
        display: 'Delete blocks, and enter insert mode'
        insert: true
        fn: () ->
          @view.delBlocks @repeat, {addNew: true}
      MOTION:
        display: 'Delete from cursor with motion, and enter insert mode'
        insert: true
        fn: (cursor) ->
          @view.deleteBetween @view.cursor, cursor, {cursor: 'pastEnd', yank: true}

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
        fn: (cursor) ->
          @view.yankBetween @view.cursor, cursor
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

  # for insert mode

  EXIT_INSERT:
    display: 'Exit insert mode'
    normal: true
    fn: () ->
       do @view.cursor.left
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

  MODES =
    NORMAL: 0
    INSERT: 1
    EX: 2
    MENU: 3

  defaultVimKeyBindings =
    INSERT:
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
      'EXIT_INSERT'       : ['esc', 'ctrl+c']
    NORMAL:
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
      'ZOOM_OUT'          : ['[', 'alt+h', 'ctrl+left']
      'ZOOM_IN'           : [']', 'alt+l', 'ctrl+right']
      'ZOOM_OUT_ALL'      : ['{']
      'ZOOM_IN_ALL'       : ['}']
      'SCROLL_DOWN'       : ['ctrl+d']
      'SCROLL_UP'         : ['ctrl+u']

      'SEARCH'            : ['/', 'ctrl+f']
      'RECORD_MACRO'      : ['q']
      'PLAY_MACRO'        : ['@']

      'EXPORT'            : ['ctrl+s']


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

  constructor: (view, divs = {}) ->
    @view = view

    @keyMaps = _.clone defaultVimKeyBindings

    @bindings = {}
    @bindings[MODES.NORMAL] = getBindings keyDefinitions, @keyMaps.NORMAL
    @bindings[MODES.INSERT] = getBindings keyDefinitions, @keyMaps.INSERT

    if divs.keyBindingsDiv
      @keybindingsDiv = divs.keyBindingsDiv
      do @buildBindingsDiv

    if divs.menuDiv
      @menuDiv = divs.menuDiv

    if divs.modeDiv
      @modeDiv = divs.modeDiv

    @mode = ''
    @setMode MODES.NORMAL

    @macros = {}
    @recording = null
    @recording_key = null

    @keyStream = new KeyStream
    @keyStream.on 'save', () =>
      do @view.save

  buildBindingsDiv: () ->
    table = $('<table>')

    buildTableContents = (definitions, onto) =>
      for k,v of definitions
        if k == 'MOTION'
          keys = ['<MOTION>']
        else
          keys = @keyMaps.NORMAL[k]
          if not keys
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
    else
      fn = info.fn
      args = []
      context = {
        view: @view,
        repeat: 1,
        setMode: @setMode
      }
      fn.apply context, args

      if info.normal
        @setMode MODES.NORMAL
        return do keyStream.save

  processMenuMode: (key) ->
    view = @menu.view

    if key == 'left'
      do view.cursor.left
      do @menu.render
    else if key == 'right'
      view.cursor.right {cursor: 'pastEnd'}
      do @menu.render
    else if key == 'up' or key == 'ctrl+k' or key == 'shift+tab'
      do @menu.up
    else if key == 'down' or key == 'ctrl+j' or key == 'tab'
      do @menu.down
    else if key == 'enter'
      do @menu.select
      do @view.save # b/c could've zoomed
      @setMode MODES.NORMAL
    else if key == 'backspace'
      do view.deleteAtCursor
      do @menu.update
    else if key == 'shift+backspace'
      view.delCharsAfterCursor 1
      do @menu.update
    else
      view.addCharsAtCursor [key], {cursor: 'pastEnd'}
      do @menu.update

  processNormalMode: (keyStream, bindings = @bindings[MODES.NORMAL], repeat = 1) ->

    # useful when you expect a motion
    getMotion = (motionKey, bindings, repeat = 1) =>
      [motionRepeat, motionKey] = getRepeat motionKey
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
        answer = (getMotion null, info.bindings, repeat)
        return answer
      else if info.fn
        fn = info.fn

      return [fn, repeat]

    # takes key, returns repeat number and key
    getRepeat = (key = null) =>
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

    [newrepeat, key] = do getRepeat
    if key == null then return do keyStream.wait
    # TODO: something better for passing repeat through?
    repeat = repeat * newrepeat

    fn = null
    args = []

    if not (key of bindings)
      if 'MOTION' of bindings
        info = bindings['MOTION']

        # note: this uses original bindings to determine what's a motion
        [motion, repeat] = getMotion key, @bindings[MODES.NORMAL], repeat
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
      [motion, repeat] = getMotion key, bindings, repeat
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
        setMode: @setMode
      }
      fn.apply context, args

      if info.insert
        @setMode MODES.INSERT
        return
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


  processOnce: (keyStream) ->
    if @mode == MODES.INSERT
      return @processInsertMode keyStream

    if @mode == MODES.NORMAL
      return @processNormalMode keyStream

    if @mode = MODES.MENU
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in menu mode'

      if key == 'esc' or key == 'ctrl+c'
        @setMode MODES.NORMAL
      else
        @processMenuMode key
      return do keyStream.forget

# exports
module?.exports = KeyBindings
