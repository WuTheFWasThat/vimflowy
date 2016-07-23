/*
Takes in keys, and, based on the keybindings (see keyBindings.js), manipulates the session (see session.js)

The KeyHandler class manages the state of what keys have been input, dealing with the logic for
- handling multi-key sequences, i.e. a key that semantically needs another key (e.g. the GO command, `g` in vim)
- handling motions and commands that take motions
- combining together and saving sequences of commands
  (important for the REPEAT command, `.` in vim, for macros, and for number prefixes, e.g. 3j)
- dropping sequences of commands that are invalid
- telling the session when to save (i.e. the proper checkpoints for undo and redo)
It maintains custom logic for this, for each mode.
(NOTE: hopefully this logic can be more unified!  It is currently quite fragile)

the KeyStream class is a helper class which deals with queuing and checkpointing a stream of key events
*/

import EventEmitter from './eventEmitter';
import * as errors from './errors';
// import Menu from './menu';
import * as Modes from './modes';
// import * as constants from './constants';

import * as Logger from './logger';

// const MODES = Modes.modes;

// manages a stream of keys, with the ability to
// - queue keys
// - wait for more keys
// - flush sequences of keys
// - save sequences of relevant keys
class KeyStream extends EventEmitter {
  constructor(keys = []) {
    super();

    this.queue = []; // queue so that we can read group of keys, like 123 or fy
    this.lastSequence = []; // last key sequence
    this.index = 0;
    this.checkpoint_index = 0;
    this.waiting = false;

    for (let i = 0; i < keys.length; i++) {
      let key = keys[i];
      this.enqueue(key);
    }
  }

  empty() {
    return this.queue.length === 0;
  }

  done() {
    return this.index === this.queue.length;
  }

  rewind() {
    return this.index = this.checkpoint_index;
  }

  enqueue(key) {
    this.queue.push(key);
    return this.waiting = false;
  }

  dequeue() {
    if (this.index === this.queue.length) { return null; }
    return this.queue[this.index++];
  }

  checkpoint() {
    return this.checkpoint_index = this.index;
  }

  // means we are waiting for another key before we can do things
  wait() {
    this.waiting = true;
    return this.rewind();
  }

  save() {
    let processed = this.forget();
    this.lastSequence = processed;
    return this.emit('save');
  }

  // forgets the most recently processed n items
  forget(n = null) {
    if (n === null) {
      // forget everything remembered, by default
      n = this.index;
    }

    errors.assert((this.index >= n));
    let dropped = this.queue.splice((this.index-n), n);
    this.index = this.index - n;
    return dropped;
  }
}

class KeyHandler extends EventEmitter {

  constructor(session, keyBindings) {
    super();
    this.getMotion = this.getMotion.bind(this);
    this.session = session;

    this.keyBindings = keyBindings;

    this.macros = this.session.document.store.getMacros();
    this.recording = {
      stream: null,
      key: null
    };

    this.keyStream = new KeyStream();
    this.keyStream.on('save', () => {
      return this.session.save();
    });
  }

  //###########
  // for macros
  //###########

  beginRecording(key) {
    this.recording.stream = new KeyStream();
    return this.recording.key = key;
  }

  finishRecording() {
    let macro = this.recording.stream.queue;
    this.macros[this.recording.key] = macro;
    this.session.document.store.setMacros(this.macros);
    this.recording.stream = null;
    return this.recording.key = null;
  }

  async playRecording(recording) {
    // the recording shouldn't save, (i.e. no @session.save)
    let recordKeyStream = new KeyStream(recording);
    return await this.processKeys(recordKeyStream);
  }

  //##################
  // general handling
  //##################

  async handleKey(key) {
    Logger.logger.debug('Handling key:', key);
    this.keyStream.enqueue(key);
    if (this.recording.stream) {
      this.recording.stream.enqueue(key);
    }
    let handled = await this.processKeys(this.keyStream);
    return handled;
  }

  // NOTE: handled tells the eventEmitter whether to preventDefault or not
  //       returns whether all keys were handled
  //       ( NOTE: should it be whether the *last key* was handled? )
  async processKeys(keyStream) {
    let handledAll = true;
    while (!keyStream.done() && !keyStream.waiting) {
      keyStream.checkpoint();
      const { handled, fn, args, context } = this.getCommand(this.session.mode, keyStream);
      if (!handled) {
        handledAll = false;
        let mode_obj = Modes.getMode(this.session.mode);
        mode_obj.handle_bad_key(keyStream);
      } else if (fn) {
        await fn.apply(context, args);
        let mode_obj = Modes.getMode(this.session.mode);
        mode_obj.every(this.session, keyStream);
      }
    }
    return handledAll;
  }


  // returns:
  //   handled: whether we processed all keys (did not encounter a bad key)
  //   fn: a function to apply
  //   args: arguments to apply
  //   context: a context to execute the function in
  getCommand(mode, keyStream, bindings = null, repeat = 1) {
    if (bindings === null) {
      bindings = this.keyBindings.bindings[mode];
    }

    let context = {
      mode,
      session: this.session,
      repeat,
      keyStream,
      keyHandler: this
    };

    let mode_obj = Modes.getMode(mode);

    let key = keyStream.dequeue();

    let args = [];

    [key, context] = mode_obj.transform_key(key, context);
    if (key === null) {
      // either key was already null, or
      // a transform acted (which, for now, we always consider not bad.  could change)
      return {
        handled: true
      };
    }

    let info;
    if (key in bindings) {
      info = bindings[key];
    } else {
      if (!('MOTION' in bindings)) {
        return {
          handled: false
        };
      }

      // note: this uses original bindings to determine what's a motion
      let [motion, motionrepeat, handled] =
        this.getMotion(keyStream, key, this.keyBindings.motion_bindings[mode], context.repeat);
      context.repeat = motionrepeat;
      if (motion === null) {
        return {
          handled
        };
      }

      args.push(motion);
      info = bindings['MOTION'];
    }

    let { definition } = info;
    if (typeof definition === 'object') {
      // recursive definition
      return this.getCommand(mode, keyStream, info.definition, context.repeat);
    } else if (typeof definition === 'function') {
      context = mode_obj.transform_context(context);
      return {
        handled: true,
        fn: info.definition,
        args: args,
        context: context,
      };
    } else {
      throw new errors.UnexpectedValue('definition', definition);
    }
  }

  // NOTE: this should maybe be normal-mode specific
  //       but it would also need to be done for the motions
  // takes keyStream, key, returns repeat number and key
  getRepeat(keyStream, key = null) {
    if (key === null) {
      key = keyStream.dequeue();
    }
    let begins = [1, 2, 3, 4, 5, 6, 7, 8, 9].map((x => x.toString()));
    let continues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((x => x.toString()));
    if (begins.indexOf(key) === -1) {
      return [1, key];
    }
    let numStr = key;
    key = keyStream.dequeue();
    if (key === null) { return [null, null]; }
    while (continues.indexOf(key) !== -1) {
      numStr += key;
      key = keyStream.dequeue();
      if (key === null) { return [null, null]; }
    }
    return [parseInt(numStr), key];
  }

  // useful when you expect a motion
  getMotion(keyStream, motionKey, bindings, repeat) {
    let motionRepeat;
    [motionRepeat, motionKey] = this.getRepeat(keyStream, motionKey);
    repeat = repeat * motionRepeat;

    if (motionKey === null) {
      keyStream.wait();
      return [null, repeat, true];
    }

    if (!(motionKey in bindings)) {
      return [null, repeat, false];
    }

    let { definition } = bindings[motionKey];
    if (typeof definition === 'object') {
      // recursive definition
      return (this.getMotion(keyStream, null, definition, repeat));
    } else if (typeof definition === 'function') {
      let context = {
        session: this.session,
        repeat,
        keyStream,
        keyHandler: this
      };
      let motion = definition.apply(context, []);
      return [motion, repeat, true];
    } else {
      throw new errors.UnexpectedValue('definition', definition);
    }
  }
}

export default KeyHandler;
