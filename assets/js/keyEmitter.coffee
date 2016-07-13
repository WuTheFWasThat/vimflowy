Logger = require './logger.coffee'
EventEmitter = require './eventEmitter.js'

###
KeyEmitter is an EventEmitter that emits keys
A key corresponds to a keypress in the browser, including modifiers/special keys

The core function is to take browser keypress events, and normalize the key to have a string representation.

For more info, see its consumer, keyHandler.coffee, as well as keyBindings.coffee
Note that one-character keys are treated specially, in that they are insertable in insert mode.
###

class KeyEmitter extends EventEmitter

  # SEE: http://stackoverflow.com/questions/9847580/how-to-detect-safari-chrome-ie-firefox-and-opera-browser
  isOpera = !!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0 # Opera 8.0+
  isSafari = Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0 # Safari 3+
  isChrome = !!window.chrome && !isOpera # Chrome 1+
  isFirefox = typeof InstallTrigger != 'undefined' # Firefox 1.0+

  if not isChrome and not isFirefox and not isSafari
    alert('Unsupported browser!  Please use a recent Chrome, Firefox, or Safari')

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
    32: 'space'

    33: 'page up'
    34: 'page down'
    37: 'left'
    38: 'up'
    39: 'right'
    40: 'down'

    46: 'delete'

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

  if isFirefox
    keyCodeMap[173] = '-'

  constructor: () ->
    super

  listen: () ->
    $(document).keydown (e) =>
      if e.keyCode of ignoreMap
        return true
      if e.keyCode of keyCodeMap
        key = keyCodeMap[e.keyCode]
      else
        # this is necessary for typing stuff..
        key = String.fromCharCode e.keyCode

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

      Logger.logger.debug 'keycode', e.keyCode, 'key', key
      results = @emit 'keydown', key
      # return false to stop propagation, if any handler handled the key
      return not _.some results

module.exports = KeyEmitter
