/*
Takes in keys, and, based on the keybindings (see keyBindings.ts),
manipulates the session (see session.ts)

The KeyHandler class manages the state of what keys have been input, dealing with the logic for
- handling multi-key sequences, i.e. a key that semantically needs another key (e.g. the GO command, `g` in vim)
- handling motions and commands that take motions
- combining together and saving sequences of commands
  (important for the REPEAT command, `.` in vim, for macros, and for number prefixes, e.g. 3j)
- dropping sequences of commands that are invalid
- telling the session when to save (i.e. the proper checkpoints for undo and redo)
It maintains custom logic for this, for each mode.
(NOTE: hopefully this logic can be more unified!  It is currently quite fragile)
*/

// TODO/NOTE: for now, macros/repeat sequences still save keys and not commands
// it's tricky to fix due to
// the commands not being serializable (e.g. in the case where arguments are motions)
// or when the command awaits from keyStream

import EventEmitter from './utils/eventEmitter';
import logger from '../../shared/utils/logger';
import Queue from './utils/queue';
import Session from './session';
import KeyBindings, { KeyBindingsTree } from './keyBindings';
import { Motion, Action, ActionContext, motionKey, SequenceAction } from './keyDefinitions';
// import Menu from './menu';
import * as Modes from './modes';
// import * as constants from './constants';

import { Key } from './types';

// Simple stream class where you can
// enqueue synchronously, and dequeue asynchronously
// (waiting for the next enqueue if nothing is available)
export class KeyStream extends EventEmitter {
  private queue: Queue<Key>;

  public lastSequence: Array<Key>;
  private curSequence: Array<Key>;
  // where up to curSequence to actually keep
  private saveIndex: number;

  constructor(keys: Array<Key> = []) {
    super();
    this.queue = new Queue<Key>(keys);

    this.lastSequence = [];
    this.curSequence = [];
    this.saveIndex = 0;
  }

  public empty() {
    return this.queue.empty();
  }

  public async dequeue(): Promise<Key> {
    const val = await this.queue.dequeue();
    this.curSequence.push(val);
    this.emit('dequeue', val);
    return val;
  }

  public enqueue(val: Key) {
    this.queue.enqueue(val);
  }

  public stop() {
    this.queue.stop();
  }

  public keep() {
    this.saveIndex = this.curSequence.length;
  }

  public drop() {
    this.curSequence = this.curSequence.slice(0, this.saveIndex);
  }

  public dropAll() {
    this.curSequence = [];
  }

  public save() {
    if (this.curSequence.length) {
      this.lastSequence = this.curSequence;
      this.curSequence = [];
      this.saveIndex = 0;
    }
  }
}

type ActionRecord = {
  action: Action,
  motion: Motion | null,
  context: ActionContext,
};

export default class KeyHandler extends EventEmitter {
  private session: Session;
  private keyBindings: KeyBindings;
  public keyStream: KeyStream;
  private processQueue: Promise<any>;

  constructor(session: Session, keyBindings: KeyBindings) {
    super();
    this.session = session;

    this.keyBindings = keyBindings;

    this.keyStream = new KeyStream();

    this.processQueue = Promise.resolve();
  }

  public async playRecording(recording: Array<Key>) {
    // the recording shouldn't save, (i.e. no @session.save)
    const oldSave = this.session.save;
    this.session.save = () => null;
    const recordKeyStream = new KeyStream(recording);
    recordKeyStream.stop();
    try {
      await this._processKeys(recordKeyStream);
    } catch (e) {
      // console.log('caught', e, e.name);
      if (e.name === 'QueueStoppedError') {
        // console.log('failed to fully play', recording);
      } else {
        throw e;
      }
    }
    this.session.save = oldSave;
  }

  // general handling

  public queueKey(key: Key) {
    logger.info('Handling key:', key);
    const ignoredKeys = ['°', '±', '³', '­­­­¯', '¯', '®']; // common media control keys
    if (ignoredKeys.includes(key)) {
      logger.info('Ignored key:', key);
      return;
    }
    this.keyStream.enqueue(key);
    this.processKeys(); // FIRE AND FORGET
  }

  private async handleRecord(keyStream: KeyStream, record: ActionRecord) {
    const old_mode = this.session.mode;
    const mode_obj = Modes.getMode(old_mode);
    let { action, context, motion } = record;
    context = await mode_obj.transform_context(context);
    logger.info('Action:', action.name);
    if (motion) {
      logger.info('Motion:', motion.name);
      context.motion = await motion.definition.call(motion.definition, context);
    }
    // logger.debug('Context:', context);
    logger.debug(`Context: { repeat: ${context.repeat} }`);

    await mode_obj.beforeEvery(action.name, context);
    if (action.metadata.sequence === SequenceAction.DROP_ALL) {
      keyStream.dropAll();
    } else if (action.metadata.sequence === SequenceAction.DROP) {
      keyStream.drop();
    } else {
      keyStream.keep();
    }
    await action.definition.call(action.definition, context);

    const new_mode_obj = Modes.getMode(this.session.mode);
    await new_mode_obj.every(action.name, context, old_mode);
  }

  private async _processKeys(keyStream: KeyStream) {
    while (!keyStream.empty()) {
      const record = await this.getCommand(keyStream);
      if (record != null) {
        await this.handleRecord(keyStream, record);
      }
      // NOTE: needs to be outside if statement
      // in case of transformed key
      this.session.emit('handledKey');
      this.emit('handledKey');
    }
  }

  public queue(next: () => void | Promise<void>) {
    this.processQueue = this.processQueue.then(next);
    return this.processQueue;
  }

  public processKeys() {
    this.queue(async () => {
      await this._processKeys(this.keyStream);
    }).catch((err) => {
      // expose any errors
      setTimeout(() => { throw err; });
    }).then(() => {
      this.emit('processedQueue');
    });
  }

  public async getCommand(keyStream: KeyStream): Promise<ActionRecord | null> {
    const mode = this.session.mode;
    const mode_obj = Modes.getMode(mode);

    const bindings = this.keyBindings.bindings[this.session.mode];
    let key: Key | null = await keyStream.dequeue();
    let context: ActionContext = {
      mode,
      session: this.session,
      repeat: 1,
      keyStream,
      keyHandler: this,
    };

    [key, context] = await mode_obj.transform_key(key, context);
    if (key === null) {
      // a transform acted (which, for now, we always consider not bad.  could change)
      // TODO have transform key return an action?
      return null;
    }

    return this.getAction(keyStream, key, bindings, context);
  }

  public async getAction(
    keyStream: KeyStream, key: Key,
    bindings: KeyBindingsTree, context: ActionContext
  ): Promise<ActionRecord | null> {

    let info: KeyBindingsTree | Motion | Action | null = bindings.getKey(key);
    let action: Action;
    let motion: Motion | null = null;

    if (info instanceof KeyBindingsTree) {
      if (!info.hasAction) {
        return null;
      }
      key = await keyStream.dequeue();
      return await this.getAction(keyStream, key, info, context);
    }
    if (info instanceof Action) {
      action = info;
    } else if (info instanceof Motion) {
      motion = info;
      // use original bindings' motion function
      const moveInfo = this.keyBindings.bindings[context.mode].getKey(motionKey);
      if (moveInfo == null) {
        return null;
      }
      if (moveInfo instanceof KeyBindingsTree) {
        throw new Error(`${motionKey} should be registered as the final key`);
      }
      if (moveInfo instanceof Motion) {
        throw new Error(`${motionKey} should be registered for an action`);
      }
      action = moveInfo;
    } else { // info is null
      const moveInfo = bindings.getKey(motionKey);
      if (moveInfo == null) { // no handler for motion
        return null;
      }
      if (moveInfo instanceof KeyBindingsTree) {
        throw new Error(`${motionKey} should be registered as the final key`);
      }
      if (moveInfo instanceof Motion) {
        throw new Error(`${motionKey} should be registered for an action`);
      }
      action = moveInfo;
      let motion_repeat;
      [motion_repeat, key] = await this.getRepeat(keyStream, key);
      context.repeat = context.repeat * motion_repeat;
      motion = await this.getMotion(keyStream, key, this.keyBindings.bindings[context.mode]);
      if (motion === null) {
        return null;
      }
      // motion = motion;
    }

    return {
      motion,
      action,
      context,
    };
  }

  // NOTE: this should maybe be normal-mode specific
  //       but it would also need to be done for the motions
  // takes keyStream, key, returns repeat number and key
  public async getRepeat(
    keyStream: KeyStream, key: string
  ): Promise<[number, string]> {
    const begins = [1, 2, 3, 4, 5, 6, 7, 8, 9].map((x => x.toString()));
    const continues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((x => x.toString()));

    if (begins.indexOf(key) === -1) {
      return [1, key];
    }
    let numStr = '' + key;
    while (true) {
      key = await keyStream.dequeue();
      if (continues.indexOf(key) === -1) {
        break;
      }
      numStr += key;
    }
    return [parseInt(numStr, 10), key];
  }

  // useful when you expect a motion
  private async getMotion(
    keyStream: KeyStream, key: Key, bindings: KeyBindingsTree
  ): Promise<Motion | null> {
    const info = bindings.getKey(key);
    if (info == null) {
      return null;
    } else if (info instanceof KeyBindingsTree) {
      if (!info.hasMotion) {
        return null;
      }
      key = await keyStream.dequeue();
      return await this.getMotion(keyStream, key, info);
    } else if (info instanceof Action) {
      return null;
    } else {
      return info;
    }
  }
}
