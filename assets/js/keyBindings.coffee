# binds keys to manipulation of view/data

class KeyBindings

  MODES =
    NORMAL: 0
    INSERT: 1
    EX: 2

  defaultVimKeyBindings =
    HELP:
      display: 'Show/hide key bindings'
      key: '?'

    INSERT:
      display: 'Insert at character'
      key: 'i'
      insert: true
    INSERT_AFTER:
      display: 'Insert after character'
      key: 'a'
      insert: true
    INSERT_HOME:
      display: 'Insert at beginning of line'
      key: 'I'
      insert: true
    INSERT_END:
      display: 'Insert after end of line'
      key: 'A'
      insert: true
    INSERT_LINE_BELOW:
      display: 'Insert on new line after current line'
      key: 'o'
      insert: true
    INSERT_LINE_ABOVE:
      display: 'Insert on new line before current line'
      key: 'O'
      insert: true
    REPLACE:
      display: 'Replace character'
      key: 'r'

    EX:
      display: 'Enter EX mode'
      key: ':'

    UNDO:
      display: 'Undo'
      key: 'u'
    REDO:
      display: 'Redo'
      key: 'ctrl+r'
    REPEAT:
      display: 'Repeat last command'
      key: '.'


    LEFT:
      display: 'Move cursor left'
      key: 'h'
      motion: true
      alternateKeys: ['left']
    RIGHT:
      display: 'Move cursor right'
      key: 'l'
      motion: true
      alternateKeys: ['right']
    UP:
      display: 'Move cursor up'
      key: 'k'
      motion: true
      alternateKeys: ['up']
    DOWN:
      display: 'Move cursor down'
      key: 'j'
      motion: true
      alternateKeys: ['down']
    HOME:
      display: 'Move cursor to beginning of line'
      key: '0'
      motion: true
      alternateKeys: ['^']
    END:
      display: 'Move cursor to end of line'
      key: '$'
      motion: true
    BEGINNING_WORD:
      display: 'Move cursor to the first word-beginning before it'
      key: 'b'
      motion: true
    END_WORD:
      display: 'Move cursor to the first word-ending after it'
      key: 'e'
      motion: true
    NEXT_WORD:
      display: 'Move cursor to the beginning of the next word'
      key: 'w'
      motion: true
    BEGINNING_BLOCK:
      display: 'Move cursor to the first block-beginning before it'
      key: 'B'
      motion: true
    END_BLOCK:
      display: 'Move cursor to the first block-ending after it'
      key: 'E'
      motion: true
    NEXT_BLOCK:
      display: 'Move cursor to the beginning of the next block'
      key: 'W'
      motion: true
    FIND_NEXT_CHAR:
      display: 'Move cursor to next occurrence of character in line'
      key: 'f'
      motion: true
      find: true
    FIND_PREV_CHAR:
      display: 'Move cursor to previous occurrence of character in line'
      key: 'F'
      motion: true
      find: true
    TO_NEXT_CHAR:
      display: 'Move cursor to just before next occurrence of character in line'
      key: 't'
      motion: true
      find: true
    TO_PREV_CHAR:
      display: 'Move cursor to just after previous occurrence of character in line'
      key: 'T'
      motion: true
      find: true

    DELETE:
      display: 'Delete (operator)'
      key: 'd'
    CHANGE:
      display: 'Change (operator)'
      key: 'c'
    DELETE_CHAR:
      display: 'Delete character'
      key: 'x'
    DELETE_LAST_CHAR:
      display: 'Delete last character'
      key: 'X'
    CHANGE_CHAR:
      display: 'Change character'
      key: 's'
      insert: true

    YANK:
      display: 'Yank (operator)'
      key: 'y'
    PASTE_AFTER:
      display: 'Paste after cursor'
      key: 'p'
    PASTE_BEFORE:
      display: 'Paste before cursor'
      key: 'P'

    INDENT_RIGHT:
      display: 'Indent right'
      key: '>'
    INDENT_LEFT:
      display: 'Indent left'
      key: '<'
    INDENT_BLOCK_RIGHT:
      display: 'Indent block right'
      key: ']'
    INDENT_BLOCK_LEFT:
      display: 'Indent block left'
      key: '['
    TOGGLE_FOLD:
      display: 'Toggle whether a block is folded'
      key: 'z'

    SCROLL_DOWN:
      display: 'Scroll half window down'
      key: 'ctrl+d'
    SCROLL_UP:
      display: 'Scroll half window down'
      key: 'ctrl+u'

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

    @bindings = defaultVimKeyBindings
    do @buildKeyMap

    if keybindingsDiv
      @keybindingsDiv = keybindingsDiv
      do @buildBindingsDiv

    @modeDiv = modeDiv

    @mode = ''
    @setMode MODES.NORMAL

    @operator = undefined

    @queuedKeys = [] # queue so that we can read group of keys, like 123 or fy
    @curSequence = [] # current key sequence
    @lastSequence = [] # last key sequence

  buildBindingsDiv: () ->
    table = $('<table>')
    for k,v of @bindings
      row = $('<tr>')
      row.append $('<td>').text v.display
      row.append $('<td>').text v.key
      table.append row

    @keybindingsDiv.empty().append(table)


  buildKeyMap: () ->
    # reverse of bindings map
    # key -> 'STRING_DESCRIBING_ACTION'
    keyMap = {}

    # TODO: ensure no collision
    for k, v of @bindings
        keyMap[v.key] = k
        if v.alternateKeys
          for key in v.alternateKeys
            keyMap[key] = k

    @keyMap = keyMap

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

  handleMotion: (motion, options = {}) ->
    motion.repeat ?= 1

    cursor = do @view.cursor.clone

    for i in [1..motion.repeat]
      if motion.type == 'LEFT'
        cursor.left options
      else if motion.type == 'RIGHT'
        cursor.right options
      else if motion.type == 'UP'
        cursor.up options
      else if motion.type == 'DOWN'
        cursor.down options
      else if motion.type == 'HOME'
        cursor.home options
      else if motion.type == 'END'
        cursor.end options
      else if motion.type == 'BEGINNING_WORD'
        cursor.beginningWord options
      else if motion.type == 'END_WORD'
        cursor.endWord options
      else if motion.type == 'NEXT_WORD'
        cursor.nextWord options
      else if motion.type == 'BEGINNING_BLOCK'
        options.block = true
        cursor.beginningWord options
      else if motion.type == 'END_BLOCK'
        options.block = true
        cursor.endWord options
      else if motion.type == 'NEXT_BLOCK'
        options.block = true
        cursor.nextWord options
      else if motion.type == 'FIND_NEXT_CHAR'
        cursor.nextChar motion.char, options
      else if motion.type == 'TO_NEXT_CHAR'
        options.beforeFound = true
        cursor.nextChar motion.char, options
      else if motion.type == 'FIND_PREV_CHAR'
        cursor.prevChar motion.char, options
      else if motion.type == 'TO_PREV_CHAR'
        options.beforeFound = true
        cursor.prevChar motion.char, options
      else
        return null
    return cursor

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

  # returns index processed up to
  processOnce: (keys) ->

    keyIndex = 0

    nextKey = () ->
      if keyIndex == keys.length then return null
      return keys[keyIndex++]

    # useful when you expect a motion
    getMotion = (motionKey) =>
      if not motionKey
        motionKey = do nextKey
        if motionKey == null then return [null, SEQUENCE.WAIT]
      [repeat, motionKey] = getRepeat motionKey
      if motionKey == null then return [null, SEQUENCE.WAIT]

      motionBinding = @keyMap[motionKey]
      motionInfo = @bindings[motionBinding] || {}
      if not motionInfo.motion then return [null, SEQUENCE.DROP]

      motion = {type: motionBinding, repeat: repeat}
      if motionInfo.find
        char = do nextKey
        if char == null then return [null, SEQUENCE.WAIT]
        motion.char = char
      return [motion, null]

    # takes key, returns repeat number and key
    getRepeat = (key) =>
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
    seq_wait = () ->
      return [0, SEQUENCE.WAIT]
    seq_drop = () ->
      return [keyIndex, SEQUENCE.DROP]
    seq_continue = () ->
      return [keyIndex, SEQUENCE.CONTINUE]
    seq_finish = () ->
      return [keyIndex, SEQUENCE.FINISH]

    key = do nextKey
    if key == null then return do seq_wait

    # if key not in @reverseBindings then return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @mode == MODES.INSERT
      if key == 'esc' or key == 'ctrl+c'
        @setMode MODES.NORMAL
        do @view.moveCursorLeft
        return do seq_finish
      else
        if key == 'left'
          do @view.moveCursorLeft
        else if key == 'right'
          @view.moveCursorRight {cursor: 'pastEnd'}
        else if key == 'up'
          @view.moveCursorUp {cursor: 'pastEnd'}
        else if key == 'down'
          @view.moveCursorDown {cursor: 'pastEnd'}
        else if key == 'backspace'
          @view.delCharsBeforeCursor 1
        else if key == 'shift+backspace'
          @view.delCharsAfterCursor 1
        else if key == 'shift+enter'
          @view.addCharsAtCursor ['\n'], {cursor: 'pastEnd'}
        else if key == 'enter'
          do @view.newLineBelow
        else if key == 'tab'
          @view.indentLine {}
        else if key == 'shift+tab'
          @view.unindentLine {}
        else
          @view.addCharsAtCursor [key], {cursor: 'pastEnd'}

        return do seq_continue
    else if @mode == MODES.NORMAL
      [repeat, key] = getRepeat key
      if key == null then return do seq_wait

      binding = @keyMap[key]
      info = @bindings[binding] || {}

      if binding == 'HELP'
        @keybindingsDiv.toggleClass 'active'
        if localStorage?
          localStorage['showKeyBindings'] = @keybindingsDiv.hasClass 'active'
        return do seq_drop
      else if info.motion
        keyIndex = 0 # easier to just redo the work (number case is annoying)
        [motion, action] = do getMotion
        if motion == null then return [keyIndex, action]

        cursor = do @view.cursor.clone
        cursor.move motion
        @view.setCursor cursor
        return do seq_drop
      else if @mode == MODES.NORMAL
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
              cursor.move motion, {cursor: 'pastEnd'}

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
        else if binding == 'REPLACE'
          replaceKey = do nextKey
          if replaceKey == null
            return do seq_wait
          num = Math.min(repeat, do @view.curLineLength - @view.cursor.col)
          newChars = (replaceKey for i in [1..num])
          @view.spliceCharsAfterCursor num, newChars, {cursor: 'beforeEnd'}
          return do seq_finish
        else if info.insert
          if binding == 'INSERT'
            # do nothing
          else if binding == 'INSERT_AFTER'
            @view.moveCursorRight {cursor: 'pastEnd'}
          else if binding == 'INSERT_HOME'
            do @view.moveCursorHome
          else if binding == 'INSERT_END'
            @view.moveCursorEnd {cursor: 'pastEnd'}
          else if binding == 'CHANGE_CHAR'
            @view.delCharsAfterCursor 1, {cursor: 'pastEnd'}, {yank: true}
          else if binding == 'INSERT_LINE_ABOVE'
            do @view.newLineAbove
          else if binding == 'INSERT_LINE_BELOW'
            do @view.newLineBelow

          @setMode MODES.INSERT
          return do seq_continue


        else if binding == 'EX'
          @setMode MODES.EX
          return do seq_drop
        else if binding == 'UNDO'
          for i in [1..repeat]
            do @view.undo
          return do seq_drop
        else if binding == 'REDO'
          for i in [1..repeat]
            do @view.redo
          return do seq_drop
        else if binding == 'REPEAT'
          if @curSequence.length != 0
            console.log('cursequence nontrivial while replaying', @curSequence)
            do @clearSequence
          for i in [1..repeat]
            @processKeys @lastSequence
          return do seq_drop
        else if binding == 'SCROLL_UP'
          @view.scrollPages -0.5
          return do seq_drop
        else if binding == 'SCROLL_DOWN'
          @view.scrollPages 0.5
          return do seq_drop
        else
          if binding == 'DELETE_LAST_CHAR'
            num = Math.min @view.cursor.col, repeat
            if num > 0
              @view.delCharsBeforeCursor num, {yank: true}
          else if binding == 'DELETE_CHAR'
            @view.delCharsAfterCursor repeat, {yank: true}
            do @view.moveCursorBackIfNeeded
          else if binding == 'INDENT_RIGHT'
            @view.indentLine {}
          else if binding == 'INDENT_LEFT'
            @view.unindentLine {}
          else if binding == 'INDENT_BLOCK_RIGHT'
            @view.indentBlock {recursive: true}
          else if binding == 'INDENT_BLOCK_LEFT'
            @view.unindentBlock {recursive: true}
          else if binding == 'PASTE_AFTER'
            do @view.pasteAfter
          else if binding == 'PASTE_BEFORE'
            do @view.pasteBefore
          else if binding == 'TOGGLE_FOLD'
            do @view.toggleBlock
          else # unknown
            return do seq_drop
          return do seq_finish

if module?
  Cursor = require('./cursor.coffee')
  actions = require('./actions.coffee')

# exports
module?.exports = KeyBindings

