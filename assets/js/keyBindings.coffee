# binds keys to manipulation of view/data

# imports
if module?
  EventEmitter = require('./eventEmitter.coffee')
  Cursor = require('./cursor.coffee')
  Menu = require('./menu.coffee')
  actions = require('./actions.coffee')

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

  # display:
  #   is displayed in keybindings help screen
  #
  # each should have 1 of the following four
  # fn:
  #   takes a view and mutates it
  # continue:
  #   a function which takes next key
  # bindings:
  #   a dictionary from keyDefinitions to functions
  # motion:
  #   if the key can be used as a motion, then this is a function
  #   taking a cursor and mutating it
  #
  keyDefinitions =
    HELP:
      display: 'Show/hide key bindings'
      drop: true
      fn: () ->
        @keybindingsDiv.toggleClass 'active'
        if localStorage?
          localStorage['showKeyBindings'] = @keybindingsDiv.hasClass 'active'
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
    BEGINNING_BLOCK:
      display: 'Move cursor to the first block-beginning before it'
      motion: true
      fn: (cursor, option) ->
        cursor.beginningWord {cursor: option, block: true}
    END_BLOCK:
      display: 'Move cursor to the first block-ending after it'
      motion: true
      fn: (cursor, option) ->
        cursor.endWord {cursor: option, block: true}
    NEXT_BLOCK:
      display: 'Move cursor to the beginning of the next block'
      motion: true
      fn: (cursor, option) ->
        cursor.nextWord {cursor: option, block: true}
    FIND_NEXT_CHAR:
      display: 'Move cursor to next occurrence of character in line'
      motion: true
      continue: (char, cursor, option) ->
        cursor.nextChar char, {cursor: option}
    FIND_PREV_CHAR:
      display: 'Move cursor to previous occurrence of character in line'
      motion: true
      continue: (char, cursor, option) ->
        cursor.prevChar char, {cursor: option}
    TO_NEXT_CHAR:
      display: 'Move cursor to just before next occurrence of character in line'
      motion: true
      continue: (char, cursor, option) ->
        cursor.nextChar char, {cursor: option, beforeFound: true}
    TO_PREV_CHAR:
      display: 'Move cursor to just after previous occurrence of character in line'
      motion: true
      continue: (char, cursor, option) ->
        cursor.prevChar char, {cursor: option, beforeFound: true}

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
    GO_END:
      display: 'Go to end of visible document'
      motion: true
      fn: (cursor, option) ->
        do cursor.visibleEnd
    DELETE:
      display: 'Delete (operator)'
    CHANGE:
      display: 'Change (operator)'
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

    YANK:
      display: 'Yank (operator)'
      # continue:
      #   bindings:
      #     'YANK': () ->
      #       @view.yankBlocks @repeat
      #   motion:
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

    ZOOM_IN:
      display: 'Zoom in onto cursor'
      fn: () ->
        do @view.rootInto
    ZOOM_OUT:
      display: 'Zoom out by one level'
      fn: () ->
        do @view.rootUp
    TOGGLE_FOLD:
      display: 'Toggle whether a block is folded'
      fn: () ->
        do @view.toggleCurBlock
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
    SEARCH:
      display: 'Search'
      drop: true
      menu: (view, text) ->
        # a list of {contents, highlights, fn ]
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
    RECORD_MACRO:
      display: 'Begin/stop recording a macro'
    PLAY_MACRO:
      display: 'Play a macro'

  MODES =
    NORMAL: 0
    INSERT: 1
    EX: 2
    MENU: 3

  defaultVimKeyBindings =
    '?': 'HELP'
    'i': 'INSERT'
    'a': 'INSERT_AFTER'
    'I': 'INSERT_HOME'
    'A': 'INSERT_END'
    'o': 'INSERT_LINE_BELOW'
    'O': 'INSERT_LINE_ABOVE'
    'r': 'REPLACE'
    # ':': 'EX'
    'u': 'UNDO'
    'ctrl+r': 'REDO'
    '.': 'REPLAY'
    'h': 'LEFT'
    'left': 'LEFT'
    'l': 'RIGHT'
    'right': 'RIGHT'
    'k': 'UP'
    'up': 'UP'
    'j': 'DOWN'
    'down': 'DOWN'
    '0': 'HOME'
    '^': 'HOME'
    '$': 'END'
    'b': 'BEGINNING_WORD'
    'e': 'END_WORD'
    'w': 'NEXT_WORD'
    'B': 'BEGINNING_BLOCK'
    'E': 'END_BLOCK'
    'W': 'NEXT_BLOCK'
    'f': 'FIND_NEXT_CHAR'
    'F': 'FIND_PREV_CHAR'
    't': 'TO_NEXT_CHAR'
    'T': 'TO_PREV_CHAR'
    'g': 'GO'
    'G': 'GO_END'
    'd': 'DELETE'
    'c': 'CHANGE'
    'x': 'DELETE_CHAR'
    'X': 'DELETE_LAST_CHAR'
    's': 'CHANGE_CHAR'
    'y': 'YANK'
    'p': 'PASTE_AFTER'
    'P': 'PASTE_BEFORE'
    'J': 'JOIN_LINE'

    'tab': 'INDENT_RIGHT'
    'shift+tab': 'INDENT_LEFT'
    '>': 'MOVE_BLOCK_RIGHT'
    '<': 'MOVE_BLOCK_LEFT'
    'ctrl+l': 'MOVE_BLOCK_RIGHT'
    'ctrl+h': 'MOVE_BLOCK_LEFT'
    'ctrl+j': 'MOVE_BLOCK_DOWN'
    'ctrl+k': 'MOVE_BLOCK_UP'

    'alt+h': 'ZOOM_OUT'
    'alt+l': 'ZOOM_IN'
    'alt+j': 'NEXT_SIBLING'
    'alt+k': 'PREV_SIBLING'

    'z': 'TOGGLE_FOLD'
    '[': 'ZOOM_OUT'
    ']': 'ZOOM_IN'
    'ctrl+left': 'ZOOM_OUT'
    'ctrl+right': 'ZOOM_IN'
    'ctrl+d': 'SCROLL_DOWN'
    'ctrl+u': 'SCROLL_UP'

    '/': 'SEARCH'
    'q': 'RECORD_MACRO'
    '@': 'PLAY_MACRO'

  constructor: (view, divs = {}) ->
    @view = view

    @bindings = keyDefinitions
    @keyMap = {}
    for k, v of defaultVimKeyBindings
      @keyMap[k] = v

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
    typeToKeys = {}
    for k,v of @keyMap
      if not typeToKeys[v]
        typeToKeys[v] = []
      typeToKeys[v].push k

    table = $('<table>')

    buildTableContents = (bindings, onto) ->
      for k,v of bindings
        keys = typeToKeys[k]
        if not keys
          continue
        row = $('<tr>')
        row.append $('<td>').text keys[0]
        display_cell = $('<td>').text v.display

        row.append display_cell
        if v.continue and v.continue.bindings
          buildTableContents v.continue.bindings, display_cell
        # row.append $('<td>').text typeToKeys[k].join(' OR ')
        onto.append row

    buildTableContents @bindings, table
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

  getKey: (name) ->
    return @bindings[name].key

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

  processInsertMode: (key) ->
    view = @view
    if key == 'left'
      do view.cursor.left
    else if key == 'right'
      view.cursor.right {cursor: 'pastEnd'}
    else if key == 'up' or key == 'ctrl+k'
      view.cursor.up {cursor: 'pastEnd'}
    else if key == 'down' or key == 'ctrl+j'
      view.cursor.down {cursor: 'pastEnd'}
    else if key == 'backspace'
      do view.deleteAtCursor
    else if key == 'shift+backspace'
      view.delCharsAfterCursor 1
    else if key == 'shift+enter'
      view.addCharsAtCursor ['\n'], {cursor: 'pastEnd'}
    else if key == 'enter'
      do view.newLineAtCursor
    else if key == 'tab'
      do view.indent
    else if key == 'shift+tab'
      do view.unindent
    else
      view.addCharsAtCursor [key], {cursor: 'pastEnd'}

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

  processOnce: (keyStream) ->

    # useful when you expect a motion
    getMotion = (motionKey, bindings = @bindings) =>
      [repeat, motionKey] = getRepeat motionKey
      if motionKey == null
        do keyStream.wait
        return null

      binding = @keyMap[motionKey]
      info = bindings[binding] || {}
      if not info.motion
        do keyStream.forget
        return null

      fn = null

      if info.continue
        key = do keyStream.dequeue
        if key == null
          do keyStream.wait
          return null
        fn = info.continue.bind @, key

      else if info.bindings
        answer = (getMotion null, info.bindings)
        return answer
      else if info.fn
        fn = info.fn

      # TODO: this is weird... just return another argument
      fn.repeat = repeat
      return fn

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

    processNormalMode = (bindings) =>
      [repeat, key] = do getRepeat
      if key == null then return do keyStream.wait

      binding = @keyMap[key]
      if not binding of bindings
        return do keyStream.forget
      info = bindings[binding] || {}

      if info.motion
        motion = getMotion key
        if motion == null then return

        for j in [1..repeat]
          motion @view.cursor, ''
        return do keyStream.forget
      else if info.menu
        @setMode MODES.MENU
        @menu = new Menu @menuDiv, (info.menu.bind @, @view)
        do @menu.render
        return do keyStream.forget

      fn = null
      args = []

      if info.continue
        key = do keyStream.dequeue
        if key == null then return do keyStream.wait

        fn = info.continue
        args.push key
      else if info.bindings
        return processNormalMode info.bindings
      else if info.fn
        fn = info.fn

      if fn
        context = {
          view: @view,
          repeat: repeat,
          keybindingsDiv: @keybindingsDiv,
        }
        fn.apply context, args

        if info.insert
          @setMode MODES.INSERT
          return
        if info.drop
          return do keyStream.forget
        else
          return do keyStream.save

      if binding == 'RECORD_MACRO'
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
      if binding == 'PLAY_MACRO'
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

      if binding == 'DELETE' or binding == 'CHANGE' or binding == 'YANK'
        nkey = do keyStream.dequeue
        if nkey == null then return do keyStream.wait

        if nkey == key
          # dd and cc
          if binding == 'YANK'
            @view.yankBlocks repeat
          else
            @view.delBlocks repeat, {addNew: binding == 'CHANGE'}
        else
          motion = getMotion nkey
          if motion == null then return

          cursor = do @view.cursor.clone
          for i in [1..repeat]
            for j in [1..motion.repeat]
              motion cursor, 'pastEnd'

          if binding == 'YANK'
            @view.yankBetween @view.cursor, cursor
          else if binding == 'CHANGE'
            @view.deleteBetween @view.cursor, cursor, {cursor: 'pastEnd', yank: true}
          else
            @view.deleteBetween @view.cursor, cursor, {yank: true}

        if binding == 'CHANGE'
          @setMode MODES.INSERT
          return
        else if binding == 'YANK'
          return do keyStream.forget
        else # binding == 'DELETE'
          return do keyStream.save
      else if binding == 'REPLAY'
        for i in [1..repeat]
          newStream = new KeyStream @keyStream.lastSequence
          newStream.on 'save', () =>
            do @view.save
          @processKeys newStream
        return do keyStream.forget
      else
        return do keyStream.forget

    # if key not in @reverseBindings then return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @mode == MODES.INSERT
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in insert mode'
      # if key == null then return do keyStream.wait

      if key == 'esc' or key == 'ctrl+c'
        @setMode MODES.NORMAL
        do @view.cursor.left
        return do keyStream.save
      else
        @processInsertMode key
        return

    if @mode == MODES.NORMAL
      return processNormalMode @bindings

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

