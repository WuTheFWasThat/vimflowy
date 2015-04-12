class KeyHandler extends EventEmitter

  shiftMap =
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
    '/': '?'

  keyCodeMap =
    8: 'backspace'
    13: 'enter'
    27: 'esc'

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

    191: '/'

  for i in [1..26]
    keyCode = i + 64
    letter = String.fromCharCode keyCode
    lower = do letter.toLowerCase
    keyCodeMap[keyCode] = lower
    shiftMap[lower] = letter

  constructor: () ->
    super

  listen: () ->
    self = @
    $(document).keydown (e) ->
      if e.keyCode of keyCodeMap
        key = keyCodeMap[e.keyCode]

        if e.shiftKey
          if key of shiftMap
            key = shiftMap[key]
          else
            key = 'shift+'

        if e.ctrlKey
          key = 'ctrl+' + key

        self.emit 'keydown', key
      console.log('keycode', e.keyCode, 'key', key)

