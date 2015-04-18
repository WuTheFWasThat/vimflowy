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
      operator: true

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
      operator: true
    CHANGE:
      display: 'Change (operator)'
      key: 'c'
      operator: true
    DELETE_CHAR:
      display: 'Delete character'
      key: 'x'
    CHANGE_CHAR:
      display: 'Change character'
      key: 's'
      insert: true

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
    console.log(@keybindingsDiv)


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

  setOperator: (operator) ->
    @operator = operator

  getKey: (name) ->
    return @bindings[name].key

  continueSequence: (key) ->
    @curSequence.push key
    # console.log('cursequence', @curSequence)

  registerSequence: () ->
    @lastSequence = @curSequence
    do @clearSequence

  finishSequence: (key) ->
    @continueSequence key
    do @registerSequence

  clearSequence: () ->
    @curSequence = []

  handleMotion: (motion, options) ->
    if motion == 'LEFT'
      return @view.cursorLeft options
    if motion == 'RIGHT'
      return @view.cursorRight options
    if motion == 'HOME'
      return @view.cursorHome options
    if motion == 'END'
      return @view.cursorEnd options
    if motion == 'BEGINNING_WORD'
      return @view.cursorBeginningWord options
    if motion == 'END_WORD'
      return @view.cursorEndWord options
    if motion == 'NEXT_WORD'
      return @view.cursorNextWord options
    return null

  handleKeys: (keys) ->
    for key in keys
      @handleKey key

  handleKey: (key) ->
    # if key not in @reverseBindings:
    #     return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @mode == MODES.INSERT
      if key == 'esc' or key == 'ctrl+c'
        @setMode MODES.NORMAL
        do @view.moveCursorLeft

        @finishSequence key
      else
        if key == 'left'
          do @view.moveCursorLeft
        else if key == 'right'
          do @view.moveCursorRight
        else if key == 'backspace'
          @view.act new actions.DelChars @view.curRow, (@view.curCol-1), 1
        else
          @view.act new actions.AddChars @view.curRow, @view.curCol, [key], {pastEnd: true}

        @continueSequence key
    else if @mode == MODES.NORMAL
      if key not of @keyMap
        do @clearSequence
        do @setOperator
        return

      binding = @keyMap[key]
      info = @bindings[binding]

      if not @operator
        if binding == 'HELP'
          @keybindingsDiv.toggleClass 'active'
        else if info.motion
          [row, col] = @handleMotion binding
          @view.moveCursor row, col
        else if @mode == MODES.NORMAL

          if info.operator
            if binding == 'DELETE'
              @setOperator 'DELETE'
            else if binding == 'CHANGE'
              @setOperator 'CHANGE'
            else if binding == 'REPLACE'
              @setOperator 'REPLACE'

            @continueSequence key
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
              @view.act new actions.DelChars @view.curRow, @view.curCol, 1, {pastEnd: true}

            @setMode MODES.INSERT

            @continueSequence key
          else
            if binding == 'EX'
              @setMode MODES.EX
            else if binding == 'UNDO'
              do @view.undo
            else if binding == 'REDO'
              do @view.redo
            else if binding == 'REPEAT'
              # console.log('replaying', @lastSequence)
              @handleKeys @lastSequence
            else if binding == 'DELETE_CHAR'
              @view.act new actions.DelChars @view.curRow, @view.curCol, 1
              do @view.moveCursorBackIfNeeded

              @finishSequence key

      else if @operator == 'REPLACE'
        @view.act new actions.SpliceChars @view.curRow, @view.curCol, 1, [key], {cursor: 'stay'}

        @finishSequence key
        do @setOperator
      else if @operator == 'DELETE' or @operator == 'CHANGE'
        if info.motion
          [row, col] = @handleMotion binding, {pastEnd: true}
          if col < @view.curCol
            @view.act new actions.DelChars @view.curRow, col, (@view.curCol - col)
          else if col > @view.curCol
            @view.act new actions.DelChars @view.curRow, @view.curCol, (col - @view.curCol)
          @curCol = col
          if @operator == 'CHANGE'
            @setMode MODES.INSERT
            @continueSequence key
          else
            @finishSequence key
        else
          console.log('cleared', @lastSequence)
          do @clearSequence

        do @setOperator

if module?
  actions = require('./actions.coffee')
module?.exports = KeyBindings

