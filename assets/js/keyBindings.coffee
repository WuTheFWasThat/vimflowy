# binds keys to manipulation of view/data

class KeyBindings

  # display:
  #   is displayed in keybindings help screen
  # fn:
  #   takes a view and mutates it
  # continue:
  #   either a function which takes next key
  #   or a dictionary from keyDefinitions to functions
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
        @view.moveCursorRight {cursor: 'pastEnd'}
    INSERT_HOME:
      display: 'Insert at beginning of line'
      insert: true
      fn: () ->
        do @view.moveCursorHome
    INSERT_END:
      display: 'Insert after end of line'
      insert: true
      fn: () ->
        @view.moveCursorEnd {cursor: 'pastEnd'}
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
      motion: (cursor, options) ->
        cursor.left options
    RIGHT:
      display: 'Move cursor right'
      motion: (cursor, options) ->
        cursor.right options
    UP:
      display: 'Move cursor up'
      motion: (cursor, options) ->
        cursor.up options
    DOWN:
      display: 'Move cursor down'
      motion: (cursor, options) ->
        cursor.down options
    HOME:
      display: 'Move cursor to beginning of line'
      motion: (cursor, options) ->
        cursor.home options
    END:
      display: 'Move cursor to end of line'
      motion: (cursor, options) ->
        cursor.end options
    BEGINNING_WORD:
      display: 'Move cursor to the first word-beginning before it'
      motion: (cursor, options) ->
        cursor.beginningWord options
    END_WORD:
      display: 'Move cursor to the first word-ending after it'
      motion: (cursor, options) ->
        cursor.endWord options
    NEXT_WORD:
      display: 'Move cursor to the beginning of the next word'
      motion: (cursor, options) ->
        cursor.nextWord options
    BEGINNING_BLOCK:
      display: 'Move cursor to the first block-beginning before it'
      motion: (cursor, options) ->
        options.block = true
        cursor.beginningWord options
    END_BLOCK:
      display: 'Move cursor to the first block-ending after it'
      motion: (cursor, options) ->
        options.block = true
        cursor.endWord options
    NEXT_BLOCK:
      display: 'Move cursor to the beginning of the next block'
      motion: (cursor, options) ->
        options.block = true
        cursor.nextWord options
    FIND_NEXT_CHAR:
      display: 'Move cursor to next occurrence of character in line'
      motion:
        continue: (char, cursor, options) ->
          cursor.nextChar char, options
    FIND_PREV_CHAR:
      display: 'Move cursor to previous occurrence of character in line'
      motion:
        continue: (char, cursor, options) ->
          cursor.prevChar char, options
    TO_NEXT_CHAR:
      display: 'Move cursor to just before next occurrence of character in line'
      motion:
        continue: (char, cursor, options) ->
          options.beforeFound = true
          cursor.nextChar char, options
    TO_PREV_CHAR:
      display: 'Move cursor to just after previous occurrence of character in line'
      motion:
        continue: (char, cursor, options) ->
          options.beforeFound = true
          cursor.prevChar char, options
    GO:
      display: 'Various commands for navigation (operator)'
      continue:
        bindings:
          GO:
            display: 'Go to the beginning of visible document'
            drop: true
            fn: () ->
              row = do @view.data.nextVisible
              @view.setCur row, 0
              do @view.render
    GO_END:
      display: 'Go to end of visible document'
      drop: true
      fn: () ->
        row = do @view.data.lastVisible
        @view.setCur row, 0
        do @view.render
    DELETE:
      display: 'Delete (operator)'
    CHANGE:
      display: 'Change (operator)'
    DELETE_CHAR:
      display: 'Delete character'
      fn: () ->
        @view.delCharsAfterCursor @repeat, {yank: true}
        do @view.moveCursorBackIfNeeded
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

    INDENT_RIGHT:
      display: 'Indent row right'
      fn: () ->
        @view.indentCurrent {}
    INDENT_LEFT:
      display: 'Indent row left'
      fn: () ->
        @view.unindentCurrent {}
    INDENT_BLOCK_RIGHT:
      display: 'Indent block right'
      fn: () ->
        @view.indentCurrent {recursive: true}
    INDENT_BLOCK_LEFT:
      display: 'Indent block left'
      fn: () ->
        @view.unindentCurrent {recursive: true}
    SWAP_BLOCK_DOWN:
      display: 'Move block one row downwards'
      fn: () ->
        do @view.swapCurrentDown
    SWAP_BLOCK_UP:
      display: 'Move lbock one row upwards'
      fn: () ->
        do @view.swapCurrentUp

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
      display: 'Scroll half window down'
      drop: true
      fn: () ->
        @view.scrollPages -0.5

  MODES =
    NORMAL: 0
    INSERT: 1
    EX: 2

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

    'tab': 'INDENT_RIGHT'
    'shift+tab': 'INDENT_LEFT'
    '>': 'INDENT_RIGHT'
    '<': 'INDENT_LEFT'
    'ctrl+l': 'INDENT_BLOCK_RIGHT'
    'ctrl+h': 'INDENT_BLOCK_LEFT'
    'ctrl+j': 'SWAP_BLOCK_DOWN'
    'ctrl+k': 'SWAP_BLOCK_UP'

    'z': 'TOGGLE_FOLD'
    '[': 'ZOOM_OUT'
    ']': 'ZOOM_IN'
    'ctrl+left': 'ZOOM_OUT'
    'ctrl+right': 'ZOOM_IN'
    'ctrl+d': 'SCROLL_DOWN'
    'ctrl+u': 'SCROLL_UP'

  SEQUENCE = {
    # wait for more keys
    WAIT: 0
    # drop the current sequence (bogus input)
    DROP: 1
    # continue the sequence
    CONTINUE: 2
    # finish the sequence
    FINISH: 3
  }

  constructor: (modeDiv, keybindingsDiv, view) ->
    @view = view

    @bindings = keyDefinitions
    @keyMap = {}
    for k, v of defaultVimKeyBindings
      @keyMap[k] = v

    if keybindingsDiv
      @keybindingsDiv = keybindingsDiv
      do @buildBindingsDiv

    @modeDiv = modeDiv

    @mode = ''
    @setMode MODES.NORMAL

    @queuedKeys = [] # queue so that we can read group of keys, like 123 or fy
    @curSequence = [] # current key sequence
    @lastSequence = [] # last key sequence

  buildBindingsDiv: () ->
    typeToKeys = {}
    for k,v of @keyMap
      if not typeToKeys[v]
        typeToKeys[v] = []
      typeToKeys[v].push k

    table = $('<table>')

    buildTableContents = (bindings, onto) ->
      for k,v of bindings
        row = $('<tr>')
        row.append $('<td>').text typeToKeys[k][0]
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

  getKey: (name) ->
    return @bindings[name].key

  continueSequence: (keys) ->
    for key in keys
      @curSequence.push key

  registerSequence: () ->
    @lastSequence = @curSequence
    do @clearSequence
    do @view.save

  clearSequence: () ->
    @curSequence = []

  handleKeys: (keys) ->
    for key in keys
      @queuedKeys.push key
      console.log('key', key)
    @queuedKeys = @processKeys @queuedKeys

  handleKey: (key) ->
    @handleKeys [key]

  processKeys: (keys) ->
    index = -1
    while keys.length and index != 0
      [index, seqAction] = @processOnce keys

      if seqAction == SEQUENCE.WAIT
        break

      processed = keys.splice 0, index
      if seqAction == SEQUENCE.DROP
        do @clearSequence
      else if seqAction == SEQUENCE.CONTINUE
        @continueSequence processed
      else if seqAction == SEQUENCE.FINISH
        @continueSequence processed
        do @registerSequence
    return keys

  processInsertMode: (key) ->
    if key == 'left'
      do @view.moveCursorLeft
    else if key == 'right'
      @view.moveCursorRight {cursor: 'pastEnd'}
    else if key == 'up'
      @view.moveCursorUp {cursor: 'pastEnd'}
    else if key == 'down'
      @view.moveCursorDown {cursor: 'pastEnd'}
    else if key == 'backspace'
      if @view.cursor.col == 0
        row = @view.cursor.row
        sib = @view.data.prevVisible row
        if sib != null
          @view.joinRows sib, row, {cursor: 'pastEnd'}
      else
        @view.delCharsBeforeCursor 1, {cursor: 'pastEnd'}
    else if key == 'shift+backspace'
      @view.delCharsAfterCursor 1
    else if key == 'shift+enter'
      @view.addCharsAtCursor ['\n'], {cursor: 'pastEnd'}
    else if key == 'enter'
      do @view.newLineBelow
    else if key == 'tab'
      @view.indentCurrent {}
    else if key == 'shift+tab'
      @view.unindentCurrent {}
    else
      @view.addCharsAtCursor [key], {cursor: 'pastEnd'}

  # returns index processed up to
  processOnce: (keys) ->

    keyIndex = 0

    nextKey = () ->
      if keyIndex == keys.length then return null
      return keys[keyIndex++]

    # useful when you expect a motion
    getMotion = (motionKey) =>
      [repeat, motionKey] = getRepeat motionKey
      if motionKey == null then return [null, SEQUENCE.WAIT]

      motionBinding = @keyMap[motionKey]
      motionInfo = @bindings[motionBinding] || {}
      if not motionInfo.motion then return [null, SEQUENCE.DROP]

      fn = null
      args = []

      if typeof motionInfo.motion == 'function'
        fn = motionInfo.motion
      else if typeof motionInfo.motion == 'object'
        char = do nextKey
        if char == null then return [null, SEQUENCE.WAIT]
        fn = motionInfo.motion.continue.bind @, char

      fn.repeat = repeat
      return [fn, null]

    # takes key, returns repeat number and key
    getRepeat = (key = null) =>
      if key == null
        key = do nextKey
      begins = [1..9].map ((x) -> return do x.toString)
      continues = [0..9].map ((x) -> return do x.toString)
      if key not in begins
        return [1, key]
      numStr = key
      key = do nextKey
      if key == null then return [null, null]
      while key in continues
        numStr += key
        key = do nextKey
        if key == null then return [null, null]
      return [parseInt(numStr), key]

    # hepler functions for return values
    seq_wait = () =>
      return [0, SEQUENCE.WAIT]
    seq_drop = () =>
      do @view.render
      return [keyIndex, SEQUENCE.DROP]
    seq_continue = () =>
      do @view.render
      return [keyIndex, SEQUENCE.CONTINUE]
    seq_finish = () =>
      do @view.render
      return [keyIndex, SEQUENCE.FINISH]

    processNormalMode = (bindings) =>
      [repeat, key] = do getRepeat
      if key == null then return do seq_wait

      binding = @keyMap[key]
      if not binding of bindings
        return do seq_drop
      info = bindings[binding] || {}

      if info.motion
        [motion, action] = getMotion key
        if motion == null then return [keyIndex, action]

        for j in [1..repeat]
          motion @view.cursor, {}
        return do seq_drop

      fn = null
      args = []

      if info.continue
        if typeof info.continue == 'function'
          key = do nextKey
          if key == null then return do seq_wait

          fn = info.continue
          args.push key
        else # a dictionary
          return processNormalMode(info.continue.bindings)

          # TODO
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
          return do seq_continue
        if info.drop
          return do seq_drop
        else
          return do seq_finish

      if binding == 'DELETE' or binding == 'CHANGE' or binding == 'YANK'
        nkey = do nextKey
        if nkey == null then return do seq_wait

        if nkey == key
          # dd and cc
          if binding == 'YANK'
            @view.yankBlocks repeat
          else
            @view.delBlocks repeat, {addNew: binding == 'CHANGE'}
        else
          [motion, action] = getMotion nkey
          if motion == null then return [keyIndex, action]

          cursor = do @view.cursor.clone
          for i in [1..repeat]
            for j in [1..motion.repeat]
              motion cursor, {cursor: 'pastEnd'}

          if cursor.col < @view.cursor.col
            if binding == 'YANK'
              @view.yankCharsBeforeCursor (@view.cursor.col - cursor.col)
            else
              @view.delCharsBeforeCursor (@view.cursor.col - cursor.col), {yank: true}
          else if cursor.col > @view.cursor.col
            if binding == 'YANK'
              @view.yankCharsAfterCursor (cursor.col - @view.cursor.col)
            else
              cursorOption = if binding == 'CHANGE' then 'pastEnd' else ''
              @view.delCharsAfterCursor (cursor.col - @view.cursor.col), {cursor: cursorOption, yank: true}

        if binding == 'CHANGE'
          @setMode MODES.INSERT
          return do seq_continue
        else if binding == 'YANK'
          return do seq_drop
        else # binding == 'DELETE'
          return do seq_finish
      else if binding == 'REPLAY'
        if @curSequence.length != 0
          console.log('cursequence nontrivial while replaying', @curSequence)
          do @clearSequence
        for i in [1..repeat]
          @processKeys @lastSequence
        return do seq_drop
      else
        return do seq_drop


    # if key not in @reverseBindings then return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @mode == MODES.INSERT
      key = do nextKey
      if key == null then return do seq_wait

      if key == 'esc' or key == 'ctrl+c'
        @setMode MODES.NORMAL
        do @view.moveCursorLeft
        return do seq_finish
      else
        @processInsertMode key
        return do seq_continue

    if @mode == MODES.NORMAL
      return processNormalMode @bindings

if module?
  Cursor = require('./cursor.coffee')
  actions = require('./actions.coffee')

# exports
module?.exports = KeyBindings

