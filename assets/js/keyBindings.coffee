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

  SEQUENCE_ACTIONS = {
    DROP: 0
    CONTINUE: 1
    FINISH: 2
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
      @handleKey key

  handleKey: (key) ->
    console.log 'key', key
    @queuedKeys.push key
    @queuedKeys = @processKeys @queuedKeys

  processKeys: (keys) ->
    index = -1
    while keys.length and index != 0
      try
        [index, seqAction] = @processOnce keys
      catch e
        if e == 'Need more keys'
          return keys
        console.log e.stack
        throw e
      processed = keys.splice 0, index
      if seqAction == SEQUENCE_ACTIONS.DROP
        do @clearSequence
      else if seqAction == SEQUENCE_ACTIONS.CONTINUE
        @continueSequence processed
      else if seqAction == SEQUENCE_ACTIONS.FINISH
        @continueSequence processed
        do @registerSequence
    return keys

  # returns index processed up to
  processOnce: (keys) ->

    keyIndex = 0

    nextKey = () ->
      if keyIndex == keys.length
        throw 'Need more keys'
      return keys[keyIndex++]

    # useful when you expect a motion
    getMotion = (motionKey) =>
      if not motionKey
        motionKey = do nextKey
      [repeat, motionKey] = getRepeat motionKey

      motionBinding = @keyMap[motionKey]
      motionInfo = @bindings[motionBinding] || {}
      if not motionInfo.motion
        return

      motion = {type: motionBinding, repeat: repeat}
      if motionInfo.find
        char = do nextKey
        motion.char = char
      return motion

    # takes key, returns repeat number and key
    getRepeat = (key) =>
      begins = [1..9].map ((x) -> return do x.toString)
      continues = [0..9].map ((x) -> return do x.toString)
      if key not in begins
        return [1, key]
      numStr = key
      key = do nextKey
      while key in continues
        numStr += key
        key = do nextKey
      return [parseInt(numStr), key]

    # console.log('keys', keys)
    key = do nextKey

    # if key not in @reverseBindings:
    #     return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @mode == MODES.INSERT
      if key == 'esc' or key == 'ctrl+c'
        @setMode MODES.NORMAL
        do @view.moveCursorLeft
        return [keyIndex, SEQUENCE_ACTIONS.FINISH]
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
        else if key == 'shift+enter'
          @view.addCharsAtCursor ['\n'], {cursor: 'pastEnd'}
        else if key == 'enter'
          do @view.newRowBelow
        else if key == 'tab'
          @view.indentRow {}
        else if key == 'shift+tab'
          @view.unindentRow {}
        else
          @view.addCharsAtCursor [key], {cursor: 'pastEnd'}

        return [keyIndex, SEQUENCE_ACTIONS.CONTINUE]
    else if @mode == MODES.NORMAL
      [repeat, key] = getRepeat key

      binding = @keyMap[key]
      info = @bindings[binding] || {}

      if binding == 'HELP'
        @keybindingsDiv.toggleClass 'active'
        if localStorage?
          localStorage['showKeyBindings'] = @keybindingsDiv.hasClass 'active'
        return [keyIndex, SEQUENCE_ACTIONS.DROP]
      else if info.motion
        keyIndex = 0 # easier to just redo the work (number case is annoying)
        motion = do getMotion
        if not motion
          return [keyIndex, SEQUENCE_ACTIONS.DROP]

        cursor = @handleMotion motion
        @view.setCursor cursor
        return [keyIndex, SEQUENCE_ACTIONS.DROP]
      else if @mode == MODES.NORMAL
        if binding == 'DELETE' or binding == 'CHANGE'

          nkey = do nextKey
          if nkey == key
            # dd and cc
            @view.delRows repeat, {addNew: binding == 'CHANGE'}
          else
            motion = getMotion nkey
            if not motion
              return [keyIndex, SEQUENCE_ACTIONS.DROP]

            for i in [1..repeat]
              cursor = @handleMotion motion, {cursor: 'pastEnd'}
              if cursor.col < @view.cursor.col
                @view.delCharsBeforeCursor (@view.cursor.col - cursor.col)
              else if cursor.col > @view.cursor.col
                cursorOption = if binding == 'CHANGE' then 'pastEnd' else ''
                @view.delCharsAfterCursor (cursor.col - @view.cursor.col), {cursor: cursorOption}

          if binding == 'CHANGE'
            @setMode MODES.INSERT
            return [keyIndex, SEQUENCE_ACTIONS.CONTINUE]
          else
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]

        else if binding == 'REPLACE'
          replaceKey = do nextKey
          num = Math.min(repeat, do @view.curRowLength - @view.cursor.col)
          newChars = (replaceKey for i in [1..num])
          @view.spliceCharsAfterCursor num, newChars, {cursor: 'beforeEnd'}
          return [keyIndex, SEQUENCE_ACTIONS.FINISH]
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
            @view.delCharsAfterCursor 1, {cursor: 'pastEnd'}
          else if binding == 'INSERT_LINE_ABOVE'
            do @view.newRowAbove
          else if binding == 'INSERT_LINE_BELOW'
            do @view.newRowBelow

          @setMode MODES.INSERT
          return [keyIndex, SEQUENCE_ACTIONS.CONTINUE]
        else
          if binding == 'EX'
            @setMode MODES.EX
            return [keyIndex, SEQUENCE_ACTIONS.DROP]
          else if binding == 'UNDO'
            for i in [1..repeat]
              do @view.undo
            return [keyIndex, SEQUENCE_ACTIONS.DROP]
          else if binding == 'REDO'
            for i in [1..repeat]
              do @view.redo
            return [keyIndex, SEQUENCE_ACTIONS.DROP]
          else if binding == 'REPEAT'
            if @curSequence.length != 0
              console.log('cursequence nontrivial while replaying', @curSequence)
              do @clearSequence
            for i in [1..repeat]
              @processKeys @lastSequence
            return [keyIndex, SEQUENCE_ACTIONS.DROP]
          else if binding == 'DELETE_LAST_CHAR'
            num = Math.min @view.cursor.col, repeat
            if num > 0
              @view.delCharsBeforeCursor num
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'DELETE_CHAR'
            @view.delCharsAfterCursor repeat
            do @view.moveCursorBackIfNeeded
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'INDENT_RIGHT'
            @view.indentRow {}
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'INDENT_LEFT'
            @view.unindentRow {}
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'INDENT_BLOCK_RIGHT'
            @view.indentBlock {recursive: true}
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'INDENT_BLOCK_LEFT'
            @view.unindentBlock {recursive: true}
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'PASTE_AFTER'
            do @view.pasteAfter
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'PASTE_BEFORE'
            do @view.pasteBefore
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]

          return [keyIndex, SEQUENCE_ACTIONS.DROP]

if module?
  Cursor = require('./cursor.coffee')
  actions = require('./actions.coffee')

# exports
module?.exports = KeyBindings

