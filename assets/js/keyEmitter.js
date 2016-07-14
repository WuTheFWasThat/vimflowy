import Logger from './logger.coffee';
import EventEmitter from './eventEmitter.js';

/*
KeyEmitter is an EventEmitter that emits keys
A key corresponds to a keypress in the browser, including modifiers/special keys

The core function is to take browser keypress events, and normalize the key to have a string representation.

For more info, see its consumer, keyHandler.coffee, as well as keyBindings.coffee
Note that one-character keys are treated specially, in that they are insertable in insert mode.
*/

// SEE: http://stackoverflow.com/questions/9847580/how-to-detect-safari-chrome-ie-firefox-and-opera-browser
let isOpera = !!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0; // Opera 8.0+
let isSafari = Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0; // Safari 3+
let isChrome = !!window.chrome && !isOpera; // Chrome 1+
let isFirefox = typeof InstallTrigger !== 'undefined'; // Firefox 1.0+

if (!isChrome && !isFirefox && !isSafari) {
  alert('Unsupported browser!  Please use a recent Chrome, Firefox, or Safari');
}

let shiftMap = {
  '`': '~',
  '1': '!',
  '2': '@',
  '3': '#',
  '4': '$',
  '5': '%',
  '6': '^',
  '7': '&',
  '8': '*',
  '9': '(',
  '0': ')',
  '-': '_',
  '=': '+',
  '[': '{',
  ']': '}',
  ';': ':',
  '\'': '"',
  '\\': '|',
  '[': '{',
  ']': '}',
  '.': '>',
  ',': '<',
  '/': '?'
};

let ignoreMap = {
  16: 'shift alone',
  17: 'ctrl alone',
  18: 'alt alone',
  91: 'left command alone',
  93: 'right command alone'
};

let keyCodeMap = {
  8: 'backspace',
  9: 'tab',
  13: 'enter',
  27: 'esc',
  32: 'space',

  33: 'page up',
  34: 'page down',
  37: 'left',
  38: 'up',
  39: 'right',
  40: 'down',

  46: 'delete',

  48: '0',
  49: '1',
  50: '2',
  51: '3',
  52: '4',
  53: '5',
  54: '6',
  55: '7',
  56: '8',
  57: '9',

  186: ';',
  187: '=',
  188: ',',
  189: '-',
  190: '.',
  191: '/',
  192: '`',

  219: '[',
  220: '\\',
  221: ']',
  222: '\''
};

let iterable = __range__(1, 26, true);
for (let j = 0; j < iterable.length; j++) {
  let i = iterable[j];
  let keyCode = i + 64;
  let letter = String.fromCharCode(keyCode);
  let lower = letter.toLowerCase();
  keyCodeMap[keyCode] = lower;
  shiftMap[lower] = letter;
}

if (isFirefox) {
  keyCodeMap[173] = '-';
}


class KeyEmitter extends EventEmitter {
  constructor() {
    super();
  }

  listen() {
    return $(document).keydown(e => {
      if (e.keyCode in ignoreMap) {
        return true;
      }
      if (e.keyCode in keyCodeMap) {
        var key = keyCodeMap[e.keyCode];
      } else {
        // this is necessary for typing stuff..
        var key = String.fromCharCode(e.keyCode);
      }

      if (e.shiftKey) {
        if (key in shiftMap) {
          var key = shiftMap[key];
        } else {
          var key = `shift+${key}`;
        }
      }

      if (e.altKey) {
        var key = `alt+${key}`;
      }

      if (e.ctrlKey) {
        var key = `ctrl+${key}`;
      }

      if (e.metaKey) {
        var key = `meta+${key}`;
      }

      Logger.logger.debug('keycode', e.keyCode, 'key', key);
      let results = this.emit('keydown', key);
      // return false to stop propagation, if any handler handled the key
      return !_.some(results);
    }
    );
  }
}

export default KeyEmitter;

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}