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
    INSERT_AFTER:
      display: 'Insert after character'
      key: 'a'
    INSERT_HOME:
      display: 'Insert at beginning of line'
      key: 'I'
    INSERT_END:
      display: 'Insert after end of line'
      key: 'A'
    EX:
      display: 'Enter EX mode'
      key: ':'


    UNDO:
      display: 'Undo'
      key: 'u'
    REDO:
      display: 'Redo'
      key: 'ctrl+r'

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
    END:
      display: 'Move cursor to end of line'
      key: '$'
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
    CHANGE_CHAR:
      display: 'Change character'
      key: 's'

  constructor: (modeDiv, keybindingsDiv, view) ->
    @view = view

    @bindings = defaultVimKeyBindings

    # reverse of bindings map
    @keyMap = {}

    # TODO: ensure no collision
    for k, v of @bindings
        @keyMap[v.key] = k
        if v.alternateKeys
          for key in v.alternateKeys
            @keyMap[key] = k

    if keybindingsDiv
      table = $('<table>')
      for k,v of @bindings
        row = $('<tr>')
        row.append $('<td>').text v.display
        row.append $('<td>').text v.key
        table.append row

      keybindingsDiv.empty().append(table)
      @keybindingsDiv = keybindingsDiv
      console.log(@keybindingsDiv)

    @lastSequence = [] # last key sequence

    @modeDiv = modeDiv

    @mode = ''
    @setMode MODES.NORMAL

    @operator = undefined

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

  handleMotion: (motion, options) ->
    if motion == 'LEFT'
      return @view.cursorLeft options
    if motion == 'RIGHT'
      return @view.cursorRight options
    if motion == 'HOME'
      return @view.cursorHome options
    if motion == 'END'
      return @view.cursorEnd options
    return null

  handleKey: (key) ->
    # if key not in @reverseBindings:
    #     return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @mode == MODES.INSERT
      if key == 'esc'
        @setMode MODES.NORMAL
        do @view.moveCursorLeft
      else if key == 'left'
        do @view.moveCursorLeft
      else if key == 'right'
        do @view.moveCursorRight
      else if key == 'backspace'
        @view.act new actions.DelChars @view.curRow, (@view.curCol-1), 1
      else
        @view.act new actions.AddChars @view.curRow, @view.curCol, [key], {pastEnd: true}
    else if @mode == MODES.NORMAL
      if key not of @keyMap
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
          if binding == 'INSERT'
            @setMode MODES.INSERT
          else if binding == 'INSERT_AFTER'
            @view.moveCursorRight {pastEnd: true}
            @setMode MODES.INSERT
          else if binding == 'INSERT_HOME'
            do @view.moveCursorHome
            @setMode MODES.INSERT
          else if binding == 'INSERT_END'
            @view.moveCursorEnd {pastEnd: true}
            @setMode MODES.INSERT
          else if binding == 'EX'
            @setMode MODES.EX
          else if binding == 'UNDO'
            do @view.undo
          else if binding == 'REDO'
            do @view.redo
          else if binding == 'DELETE'
            @setOperator 'DELETE'
          else if binding == 'DELETE_CHAR'
            @view.act new actions.DelChars @view.curRow, @view.curCol, 1
            do @view.moveCursorBackIfNeeded
          else if binding == 'CHANGE'
            @setOperator 'CHANGE'
          else if binding == 'CHANGE_CHAR'
            @view.act new actions.DelChars @view.curRow, @view.curCol, 1, {pastEnd: true}
            @setMode MODES.INSERT
      else if @operator == 'DELETE' or @operator == 'CHANGE'
        if info.motion
          [row, col] = @handleMotion binding, {pastEnd: true}
          if col < @view.curCol
            @view.act new actions.DelChars @view.curRow, col, (@view.curCol - col)
          else if col > @view.curCol
            @view.act new actions.DelChars @view.curRow, @view.curCol, (col - @view.curCol)
          @curCol = col
          if @operator == 'CHANGE'
            @setMode 'INSERT'
        do @setOperator

if module?
  actions = require('./actions.coffee')
module?.exports = KeyBindings

