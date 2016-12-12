import EventEmitter from './eventEmitter';
import Session from './session';
import KeyHandler, { KeyStream } from './keyHandler';
import Cursor from './cursor';
import Path from './path';
import { ModeId, CursorOptions } from './types';

// NOTE: this is a special key, which accepts any motion keys.
// It causes definition functions to take an extra cursor argument.
// For more info/context, see keyBindings.js and definitions of CHANGE/DELETE/YANK
export const motionKey = '<motion>';

type MotionName = string;
export type MotionFn = (cursor: Cursor, options: CursorOptions) => Promise<void>;
// a motion is a function taking a cursor and moving it
export type MotionDefinition = (
  context: ActionContext
) => Promise<MotionFn>;

export class Motion {
  public name: MotionName;
  public description: string;
  public definition: MotionDefinition;
  constructor(name, description, definition: MotionDefinition) {
    this.name = name;
    this.description = description;
    this.definition = definition;
  }
}

export enum SequenceAction {
  DROP,
  DROP_ALL,
  KEEP,
};
export type ActionContext = {
  mode: ModeId;
  session: Session;
  repeat: number;
  keyStream: KeyStream;
  keyHandler: KeyHandler;
  motion?: MotionFn;
  visual_line?: {
    start_i: number,
    end_i: number,
    start: Path,
    end: Path,
    parent: Path,
    num_rows: number,
  },
};
export type ActionDefinition = (context: ActionContext) => Promise<void>;
type ActionName = string;
type ActionMetadata = {
  sequence?: SequenceAction;
};
export class Action {
  public name: ActionName;
  public description: string;
  public definition: ActionDefinition;
  public metadata: ActionMetadata;
  constructor(name, description, definition: ActionDefinition, metadata?) {
    this.name = name;
    this.description = description;
    this.definition = definition;
    this.metadata = metadata || {};
  }
}

export class KeyDefinitions extends EventEmitter {
  private registry: {[name: string]: Action | Motion};

  constructor() {
    super();
    this.registry = {};
  }

  public getRegistration(name: string): Action | Motion | null {
    return this.registry[name] || null;
  }

  public registerMotion(motion: Motion) {
    if (this.registry[motion.name]) {
      throw new Error(`${motion.name} already defined!`);
    }
    this.registry[motion.name] = motion;
    this.emit('update');
  }

  public deregisterMotion(motionName: MotionName) {
    const motion = this.registry[motionName];
    if (!motion) {
      throw new Error(`Tried to deregister motion ${motionName}, but it was not registered!`);
    }
    if (motion instanceof Action) {
      throw new Error(`Tried to deregister motion ${motionName}, but it was registered as an action!`);
    }
    delete this.registry[motionName];
    this.emit('update');
  }

  public registerAction(action: Action) {
    if (this.registry[action.name]) {
      throw new Error(`${action.name} already defined!`);
    }
    this.registry[action.name] = action;
    this.emit('update');
  }

  public deregisterAction(actionName: ActionName) {
    const action = this.registry[actionName];
    if (!action) {
      throw new Error(`Tried to deregister action ${actionName}, but it was not registered!`);
    }
    if (action instanceof Motion) {
      throw new Error(`Tried to deregister action ${actionName}, but it was registered as a motion!`);
    }
    delete this.registry[actionName];
    this.emit('update');
  }
}

export default new KeyDefinitions();
