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
      else
        return null
    return cursor

  handleKeys: (keys) ->
    for key in keys
      @handleKey key

  handleKey: (key) ->
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
    getMotion = () =>
      motionKey = do nextKey
      [repeat, motionKey] = getRepeat motionKey

      motionBinding = @keyMap[motionKey]
      motionInfo = @bindings[motionBinding]

      if not motionInfo?.motion
        return null

      motion = {type: motionBinding, repeat: repeat}
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

    console.log('keys', keys)
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
          do @view.moveCursorRight
        else if key == 'backspace'
          @view.act new actions.DelChars @view.cursor.row, (@view.cursor.col-1), 1
        else
          @view.act new actions.AddChars @view.cursor.row, @view.cursor.col, [key], {pastEnd: true}

        return [keyIndex, SEQUENCE_ACTIONS.CONTINUE]
    else if @mode == MODES.NORMAL
      [repeat, key] = getRepeat key

      binding = @keyMap[key]
      info = @bindings[binding] || {}

      if binding == 'HELP'
        @keybindingsDiv.toggleClass 'active'
        return [keyIndex, SEQUENCE_ACTIONS.DROP]
      else if info.motion
        # TODO: do this by handing repeat in motion
        cursor = @handleMotion {type: binding, repeat: repeat}
        @view.moveCursor cursor.row, cursor.col
        return [keyIndex, SEQUENCE_ACTIONS.DROP]
      else if @mode == MODES.NORMAL
        if binding == 'DELETE' or binding == 'CHANGE'

          motion = do getMotion
          if not motion
            return [keyIndex, SEQUENCE_ACTIONS.DROP]

          for i in [1..repeat]
            cursor = @handleMotion motion, {pastEnd: true}
            if cursor.col < @view.cursor.col
              @view.act new actions.DelChars @view.cursor.row, cursor.col, (@view.cursor.col - cursor.col)
            else if cursor.col > @view.cursor.col
              @view.act new actions.DelChars @view.cursor.row, @view.cursor.col, (cursor.col - @view.cursor.col), {pastEnd: binding == 'CHANGE'}

          if binding == 'CHANGE'
            @setMode MODES.INSERT
            return [keyIndex, SEQUENCE_ACTIONS.CONTINUE]
          else
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]

        else if binding == 'REPLACE'
          replaceKey = do nextKey
          num = Math.min(repeat, do @view.curRowLength - @view.cursor.col)
          newChars = (replaceKey for i in [1..num])
          @view.act new actions.SpliceChars @view.cursor.row, @view.cursor.col, num, newChars, {cursor: 'beforeEnd'}
          return [keyIndex, SEQUENCE_ACTIONS.FINISH]
        else if info.insert
          if binding == 'INSERT'
            # do nothing
          else if binding == 'INSERT_AFTER'
            @view.moveCursorRight {pastEnd: true}
          else if binding == 'INSERT_HOME'
            do @view.moveCursorHome
          else if binding == 'INSERT_END'
            @view.moveCursorEnd {pastEnd: true}
          else if binding == 'CHANGE_CHAR'
            @view.act new actions.DelChars @view.cursor.row, @view.cursor.col, 1, {pastEnd: true}

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
              @view.act new actions.DelChars @view.cursor.row, @view.cursor.col-num, num
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]
          else if binding == 'DELETE_CHAR'
            @view.act new actions.DelChars @view.cursor.row, @view.cursor.col, repeat
            do @view.moveCursorBackIfNeeded
            return [keyIndex, SEQUENCE_ACTIONS.FINISH]

          return [keyIndex, SEQUENCE_ACTIONS.DROP]


if module?
  actions = require('./actions.coffee')
module?.exports = KeyBindings

