# binds keys to manipulation of view/data

class KeyBindings

  MODES =
    VISUAL: 0
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
    RIGHT:
      display: 'Move cursor right'
      key: 'l'
      motion: true
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

    # @reverseBindings = {}

    # # TODO: ensure no collision
    # for k, v of @bindings
    #     @reverseBindings[v] = k

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

    @modeDiv = modeDiv

    @mode = ''
    @setMode MODES.VISUAL

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

  handleMotion: (key) ->
    if key == @getKey 'LEFT'
      return do @view.cursorLeft
    if key == @getKey 'RIGHT'
      return do @view.cursorRight
    if key == @getKey 'HOME'
      return do @view.cursorHome
    if key == @getKey 'END'
      return do @view.cursorEnd
    return null

  handleKey: (key) ->
    # if key not in @reverseBindings:
    #     return

    # name = @reverseBindings[key]
    # handler = @handlers[name]
    # do handler

    if @operator == 'DELETE' or @operator == 'CHANGE'
      do @setOperator
    else
      if key == @getKey 'HELP'
        @keybindingsDiv.toggleClass 'active'
      else if key == 'left'
        do @view.moveCursorLeft
      else if key == 'right'
        do @view.moveCursorRight
      else if @mode == MODES.VISUAL
        if key == @getKey 'INSERT'
          @setMode MODES.INSERT
        else if key == @getKey 'INSERT_AFTER'
          @view.moveCursorRight {pastEnd: true}
          @setMode MODES.INSERT
        else if key == @getKey 'INSERT_HOME'
          do @view.moveCursorHome
          @setMode MODES.INSERT
        else if key == @getKey 'INSERT_END'
          @view.moveCursorEnd {pastEnd: true}
          @setMode MODES.INSERT
        else if key == @getKey 'EX'
          @setMode MODES.EX
        else if key == @getKey 'UNDO'
          do @view.undo
        else if key == @getKey 'REDO'
          do @view.redo
        else if key == @getKey 'DELETE'
          @setOperator 'DELETE'
        else if key == @getKey 'DELETE_CHAR'
          @view.act new actions.DelChars @view.curRow, @view.curCol, 1
          do @view.moveCursorBackIfNeeded
        else if key == @getKey 'CHANGE'
          @setOperator 'CHANGE'
        else if key == @getKey 'CHANGE_CHAR'
          @view.act new actions.DelChars @view.curRow, @view.curCol, 1
          @setMode MODES.INSERT
        else if key == @getKey 'LEFT'
          do @view.moveCursorLeft
        else if key == @getKey 'RIGHT'
          do @view.moveCursorRight
        else if key == @getKey 'HOME'
          do @view.moveCursorHome
        else if key == @getKey 'END'
          do @view.moveCursorEnd
      else if @mode == MODES.INSERT
        if key == 'esc'
          @setMode MODES.VISUAL
          do @view.moveCursorLeft
        else if key == 'backspace'
          @view.act new actions.DelChars @view.curRow, (@view.curCol-1), 1
        else
          @view.act new actions.AddChars @view.curRow, @view.curCol, [key]

if module?
  actions = require('./actions.coffee')
module?.exports = KeyBindings

