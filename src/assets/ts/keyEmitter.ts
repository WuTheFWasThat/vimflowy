import * as $ from 'jquery';
import * as _ from 'lodash';

import * as browser_utils from './utils/browser';
import EventEmitter from './utils/eventEmitter';
import logger from '../../shared/utils/logger';
import {Key} from './types';

/*
KeyEmitter is an EventEmitter that emits keys
A key corresponds to a keypress in the browser, including modifiers/special keys

The core function is to take browser keypress events, and normalize the key to have a string representation.

For more info, see its consumer, keyHandler.ts, as well as keyBindings.ts
Note that one-character keys are treated specially, in that they are insertable in insert mode.
*/

const ignoreMap: { [keyCode: number]: string } = {
  16: 'shift alone',
  17: 'ctrl alone',
  18: 'alt alone',
  225: 'right alt alone',
  91: 'left command alone',
  93: 'right command alone',
};

const specials: { [keyCode: number]: Key } = {
  8: 'backspace',
  9: 'tab',
  13: 'enter',
  27: 'esc',
  32: 'space',

  33: 'page up',
  34: 'page down',
  35: 'end',
  36: 'home',
  37: 'left',
  38: 'up',
  39: 'right',
  40: 'down',

  46: 'delete',
};

export default class KeyEmitter extends EventEmitter {
  constructor() {
    super();
  }

  public listen() {

    // IME event
    $(document).on('compositionend', (e: any) => {
      e.originalEvent.data.split('').forEach((key: string) => {
        this.emit('keydown', key);
      });
    });

    $(document).keydown(e => {

      // IME input keycode is 229, handled above
      if (e.keyCode === 229) {
        return false;
      }
      // Ignore isolated special keys
      if (e.keyCode in ignoreMap) {
        return true;
      }

      let key;
      if (e.keyCode in specials) {
        if (e.shiftKey) {
          key = `shift+${specials[e.keyCode]}`;
        } else if (e.altKey) {
          key = `alt+${String.fromCharCode(e.keyCode)}`;
        } else if (e.ctrlKey) {
          key = `ctrl+${String.fromCharCode(e.keyCode)}`;
        } else if (e.metaKey) {
          key = `meta+${String.fromCharCode(e.keyCode)}`;
        } else {
          key = specials[e.keyCode];
        }
      } else {
        key = e.key;
      }

      logger.debug(`key pressed: ${key}, keycode: ${e.keyCode}`);

      const results = this.emit('keydown', key);
      // return false to stop propagation, if any handler handled the key
      if (_.some(results)) {
        return browser_utils.cancel(e);
      }

      return true;
    });

  }
}
