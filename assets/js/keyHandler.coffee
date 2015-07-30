class KeyHandler extends EventEmitter

  shiftMap =
    '`': '~'
    '1': '!'
    '2': '@'
    '3': '#'
    '4': '$'
    '5': '%'
    '6': '^'
    '7': '&'
    '8': '*'
    '9': '('
    '0': ')'
    '-': '_'
    '=': '+'
    '[': '{'
    ']': '}'
    ';': ':'
    '\'': '"'
    '\\': '|'
    '[': '{'
    ']': '}'
    '.': '>'
    ',': '<'
    '/': '?'

  ignoreMap =
    16: 'shift alone'
    17: 'ctrl alone'
    18: 'alt alone'
    91: 'left command alone'
    93: 'right command alone'

  keyCodeMap =
    8: 'backspace'
    9: 'tab'
    13: 'enter'
    27: 'esc'

    33: 'page up'
    34: 'page down'
    37: 'left'
    38: 'up'
    39: 'right'
    40: 'down'

    48: '0'
    49: '1'
    50: '2'
    51: '3'
    52: '4'
    53: '5'
    54: '6'
    55: '7'
    56: '8'
    57: '9'

    186: ';'
    187: '='
    188: ','
    189: '-'
    190: '.'
    191: '/'
    192: '`'

    219: '['
    220: '\\'
    221: ']'
    222: '\''

  for i in [1..26]
    keyCode = i + 64
    letter = String.fromCharCode keyCode
    lower = do letter.toLowerCase
    keyCodeMap[keyCode] = lower
    shiftMap[lower] = letter

  # keys to let the browser do its thing
  # TODO: make this configurable
  ignoreKeys =
    'meta+l'   : true
    'meta+r'   : true
    'meta+c'   : true
    'meta+v'   : true
    'ctrl+tab' : true
    'ctrl+shift+tab' : true

  constructor: () ->
    super

  listen: () ->
    self = @
    $(document).keydown (e) ->
      if e.keyCode of ignoreMap
        return true
      else if e.keyCode of keyCodeMap
        key = keyCodeMap[e.keyCode]

        if e.shiftKey
          if key of shiftMap
            key = shiftMap[key]
          else
            key = 'shift+' + key

        if e.altKey
          key = 'alt+' + key

        if e.ctrlKey
          key = 'ctrl+' + key

        if e.metaKey
          key = 'meta+' + key
      else
        # this is necessary for typing stuff..
        key = String.fromCharCode e.keyCode

      if key of ignoreKeys
        return true

      console.log('keycode', e.keyCode, 'key', key)
      self.emit 'keydown', key
      return false

