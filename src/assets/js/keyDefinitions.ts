import * as _ from 'lodash';

import * as errors from './errors';
import * as Modes from './modes';
import Cursor from './cursor';
import { CursorOptions } from './types';

type HotkeysEntry = {
  // Default hotkeys for all modes
  all?: Array<string>;
  // Default hotkey for normal-like modes
  normal_like?: Array<string>;
  // Default hotkey for insert-like modes
  insert_like?: Array<string>;
};

type CommandMetadata = {
  // Name of the command
  name: string;
  // Description of the command
  description?: string;
  // Default hotkeys for the command
  default_hotkeys?: HotkeysEntry;
};

export class Command {
  private metadata: CommandMetadata;
  public name: string;
  constructor(metadata) {
    this.metadata = metadata;
    this.name = metadata.name;
  }
}

// NOTE: this is a special command, which causes definition functions
// to always takes an extra cursor argument.
// TODO: this is a hack, and should be done more properly
// For more info/context, see keyBindings.js and definitions of CHANGE/DELETE/YANK
const motionCommandName = 'MOTION';

// MOTIONS
// should have a fn, returns a motion fn (or null)
// the motion itself should take a cursor, and an options dictionary
// (it should presumably move the cursor, somehow)
// options include:
//     pastEnd: whether to allow going past the end of the line
//     pastEndWord: whether we consider the end of a word to be after the last letter

type Motion = (cursor: Cursor, options?: CursorOptions) => Promise<void>;

type MotionDefinition =
  (() => Promise<Motion>) | {[key: string]: MotionMetadata};

type MotionMetadata = {
  // Description of the action, shows in HELP menu
  description: string;
  commands?: Array<Command>;
  multirow?: boolean;
  definition?: MotionDefinition;
};

/*
The definition should have functions for each mode that it supports
The functions will be passed contexts depending on each mode
  TODO: document these
  session:
  keyStream:
  repeat:
It may also have, bindings:
    another (recursive) set of key definitions, i.e. a dictionary from command names to definitions
*/

type ActionDefinition =
  ((motion?: Motion) => Promise<void>)
  | {[key: string]: ActionMetadata};

type ActionMetadata = {
  // Description of the action, shows in HELP menu
  description: string;
  commands?: Array<Command>;
  definition?: ActionDefinition;
};

export type Commands = { [command_name: string]: Command };
export type Motions = { [command_name: string]: MotionMetadata };
export type ActionsForMode = { [command_name: string]: ActionMetadata };
export type Actions = { [mode: number]: ActionsForMode };

export class KeyDefinitions {
  // mapping from string motion name to count (number of times mapped)
  private motion_command_counts: {
    [key: string]: {
      all?: number,
      multirow?: number,
    },
  };
  // mapping for each mode from string motion name to count (number of times mapped)
  private action_command_counts_by_mode: {
    [key: string]: {
      [key: string]: number
    },
  };

  public defaultHotkeys: any; // TODO
  public commands: Commands;
  public motions: Motions;
  public actions: Actions;

  constructor() {
    // set of possible motions
    this.motion_command_counts = {};
    // set of possible commands for each mode
    this.action_command_counts_by_mode = {};

    this.defaultHotkeys = {};
    // key mappings for normal-like modes (normal, visual, visual-line)
    this.defaultHotkeys[Modes.HotkeyType.NORMAL_MODE_TYPE] = {};
    // key mappings for insert-like modes (insert, mark, menu)
    this.defaultHotkeys[Modes.HotkeyType.INSERT_MODE_TYPE] = {};

    this.commands = {};
    // nested mapping with command names indexing, leaves are definitions
    this.motions = {};
    // for each mode, nested mapping with command names indexing, leaves are definitions
    this.actions = {};
  }

  // currently used only for testing
  public clone() {
    const other = new KeyDefinitions();
    const keys = [
      'motion_command_counts', 'action_command_counts_by_mode',
      'defaultHotkeys',
      'commands', 'motions', 'actions',
    ];
    keys.forEach((key) => {
      other[key] = _.cloneDeep(this[key]);
    });
    return other;
  }

  private _add_command(mode, command) {
    // for now, don't list the motion command
    if (command.name !== motionCommandName) {
      if (!this.action_command_counts_by_mode[mode]) {
        this.action_command_counts_by_mode[mode] = {};
      }
      const count = this.action_command_counts_by_mode[mode][command.name] || 0;
      this.action_command_counts_by_mode[mode][command.name] = count + 1;
    }
  }

  private _remove_command(mode, command) {
    // for now, don't list the motion command
    if (command.name !== motionCommandName) {
      if (!this.action_command_counts_by_mode[mode]) {
        this.action_command_counts_by_mode[mode] = {};
      }
      const count = this.action_command_counts_by_mode[mode][command.name] || 0;
      if (count === 0) {
        throw new errors.GenericError(`Cannot remove command ${command}`);
      } else if (count === 1) {
        delete this.action_command_counts_by_mode[mode][command.name];
      } else {
        this.action_command_counts_by_mode[mode][command.name] = count - 1;
      }
    }
  }

  private _add_motion(command, multirow) {
    const counts = this.motion_command_counts[command.name] || {};
    if (multirow) {
      counts.multirow = (counts.multirow || 0) + 1;
    }
    counts.all = (counts.all || 0) + 1;
    this.motion_command_counts[command.name] = counts;
  }

  private _remove_motion(command, multirow) {
    const counts = this.motion_command_counts[command.name] || {};
    if (multirow) {
      if (counts.multirow === 0) {
        throw new errors.GenericError(`Cannot remove multirow motion ${command}`);
      }
      counts.multirow = (counts.multirow || 0) - 1;
    }
    if (counts.all === 0) {
      throw new errors.GenericError(`Cannot remove motion ${command}`);
    } else if (counts.all === 1) {
      delete this.motion_command_counts[command.name];
    } else {
      counts.all = (counts.all || 0) - 1;
      this.motion_command_counts[command.name] = counts;
    }
  }

  public get_motions(multirow) {
    const result: Array<string> = [];
    for (const name in this.motion_command_counts) {
      const counts = this.motion_command_counts[name];
      if (multirow) {
        result.push(name);
      } else {
        if (counts.multirow === 0) {
          result.push(name);
        }
      }
    }
    return result;
  }

  public commands_for_mode(mode) {
    if (!(mode in this.action_command_counts_by_mode)) {
      return [];
    }
    return Object.keys(this.action_command_counts_by_mode[mode]);
  }

  public actions_for_mode(mode) {
    return this.actions[mode] || {};
  }

  public registerCommand(metadata: CommandMetadata) {
    const { name } = metadata;
    const command = new Command(metadata);

    if (command.name in this.commands) {
      throw new errors.GenericError(`Command ${command.name} has already been defined`);
    }

    this.commands[name] = command;
    this.defaultHotkeys[Modes.HotkeyType.NORMAL_MODE_TYPE][name] =
      _.cloneDeep(
        (metadata.default_hotkeys && metadata.default_hotkeys.all) || []
      ).concat(
        _.cloneDeep(
          (metadata.default_hotkeys && metadata.default_hotkeys.normal_like) || []
        )
      );
    this.defaultHotkeys[Modes.HotkeyType.INSERT_MODE_TYPE][name] =
      _.cloneDeep(
        (metadata.default_hotkeys && metadata.default_hotkeys.all) || []
      ).concat(
        _.cloneDeep(
          (metadata.default_hotkeys && metadata.default_hotkeys.insert_like) || []
        )
      );
    return command;
  }

  public deregisterCommand(command) {
    if (!(command.name in this.commands)) {
      throw new errors.GenericError(`Command ${command.name} not found`);
    }
    delete this.commands[command.name];
    delete this.defaultHotkeys[Modes.HotkeyType.NORMAL_MODE_TYPE][command.name];
    delete this.defaultHotkeys[Modes.HotkeyType.INSERT_MODE_TYPE][command.name];
  }

  public registerMotion(
    commands, motion: MotionMetadata, definition: MotionDefinition
  ) {
    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    motion = _.cloneDeep(motion);
    motion.definition = definition;
    motion.commands = commands;

    let obj = this.motions as MotionDefinition;
    let command;
    for (let k = 0; k < commands.length - 1; k++) {
      command = commands[k];
      if (!(command.name in obj)) {
        throw new errors.GenericError(`Motion ${command.name} doesn't exist`);
      } else if (typeof obj[command.name] !== 'object') {
        throw new errors.GenericError `Motion ${command.name} allows no subcommands`;
      }
      obj = obj[command.name].definition;
    }

    command = commands[commands.length - 1];

    // motion.name = command.name
    if (command.name in obj) {
      throw new errors.GenericError(`Motion ${command.name} has already been defined`);
    }
    obj[command.name] = motion;
    commands.forEach((cmd) => this._add_motion(cmd, motion.multirow));
  }

  public deregisterMotion(commands) {
    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    let obj = this.motions as MotionDefinition;
    let command;
    for (let k = 0; k < commands.length - 1; k++) {
      command = commands[k];
      if (!(command.name in obj)) {
        throw new errors.GenericError(`Motion ${command.name} doesn't exist`);
      } else if (typeof obj[command.name] !== 'object') {
        throw new errors.GenericError `Motion ${command.name} allows no subcommands`;
      }
      obj = obj[command.name].definition;
    }

    command = commands[commands.length - 1];
    // motion.name = command.name
    if (!(command.name in obj)) {
      throw new errors.GenericError(`Motion ${command.name} not found`);
    }
    const motion = obj[command.name];
    delete obj[command.name];
    commands.forEach((cmd) => this._remove_motion(cmd, motion.multirow));
  }

  public registerAction(
    modes, commands, action: ActionMetadata, definition: ActionDefinition
  ) {
    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    action = _.cloneDeep(action);
    action.definition = definition;
    action.commands = commands;

    modes.forEach((mode) => {
      if (!this.actions[mode]) {
        this.actions[mode] = {};
      }
      let obj = this.actions[mode] as ActionDefinition;

      let command;
      for (let k = 0; k < commands.length - 1; k++) {
        command = commands[k];

        if (!(command.name in obj)) {
          throw new errors.GenericError(`Action ${command.name} doesn't exist`);
        } else if (typeof obj[command.name] !== 'object') {
          throw new errors.GenericError `Action ${command.name} allows no subcommands`;
        }
        obj = obj[command.name].definition;
      }

      command = commands[commands.length - 1];
      // action.name = command.name
      if (command.name in obj) {
        throw new errors.GenericError(`Action ${command.name} has already been defined`);
      }

      obj[command.name] = action;
      commands.forEach((cmd) => this._add_command(mode, cmd));
    });
  }

  public deregisterAction(modes, commands) {
    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    modes.forEach((mode) => {
      if (!this.actions[mode]) {
        this.actions[mode] = {};
      }
      let obj = this.actions[mode] as ActionDefinition;

      let command;
      for (let k = 0; k < commands.length - 1; k++) {
        command = commands[k];

        if (!(command.name in obj)) {
          throw new errors.GenericError(`Action ${command.name} doesn't exist`);
        } else if (typeof obj[command.name] !== 'object') {
          throw new errors.GenericError `Action ${command.name} allows no subcommands`;
        }
        obj = obj[command.name].definition;
      }

      command = commands[commands.length - 1];
      // action.name = command.name
      if (!(command.name in obj)) {
        throw new errors.GenericError(`Action ${command.name} not found`);
      }

      delete obj[command.name];
      commands.forEach((cmd) => this._remove_command(mode, cmd));
    });
  }
}

export default new KeyDefinitions();
