# binds keys to manipulation of view/data

defaultVimKeyBindings = {
      'Insert after character': 'a',
      'Insert at character': 'i',

      'Undo': 'u',
      'Redo': 'ctrl+r',

      'Enter EX mode': ':',

      'Move cursor left': 'h',
      'Move cursor right': 'l',

      'Delete character': 'x',
}

class KeyBindings
  constructor: (keyHandler, modeDiv, view) ->
    @keyHandler = keyHandler
    keyHandler.on 'keydown', @handleKey.bind(@)

    @view = view

    @bindings = defaultVimKeyBindings

    # @reverseBindings = {}

    # # TODO: ensure no collision
    # for k, v of @bindings
    #     @reverseBindings[v] = k

    @modeDiv = modeDiv

    @mode = ''
    @setMode MODES.VISUAL

  setMode: (mode) ->
    console.log('setting mode', mode)
    @mode = mode
    console.log('set mode', @mode)
    for k, v of MODES
      if v == mode
        @modeDiv.text k
        break

  handleKey: (key) ->
    # if key not in @reverseBindings:
    #     return

    # action = @reverseBindings[key]
    # handler = @handlers[action]
    # do handler

    if @mode == MODES.VISUAL
      if key == @bindings['Insert after character']
        @view.moveCursorRight {pastEnd: true}
        @setMode MODES.INSERT
      else if key == @bindings['Insert at character']
        @setMode MODES.INSERT
      else if key == @bindings['Enter EX mode']
        @setMode MODES.EX
      else if key == @bindings['Undo']
        do @view.undo
      else if key == @bindings['Redo']
        do @view.redo
      else if key == @bindings['Move cursor left']
        do @view.moveCursorLeft
      else if key == @bindings['Move cursor right']
        do @view.moveCursorRight
      else if key == @bindings['Delete character']
        @view.act new DelChars @view.curRow, @view.curCol, 1
        do @view.moveCursorBackIfNeeded
    else if @mode == MODES.INSERT
      if key == 'esc'
        @setMode MODES.VISUAL
        do @view.moveCursorBackIfNeeded
      else if key == 'backspace'
        @view.act new DelChars @view.curRow, (@view.curCol-1), 1
      else
        @view.act new AddChars @view.curRow, @view.curCol, [key]
