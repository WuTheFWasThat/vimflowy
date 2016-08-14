import _ from 'lodash';

import * as utils from './utils';
import * as errors from './errors';
import * as Modes from './modes';

class Command {
  constructor(metadata) {
    this.metadata = metadata;
    this.name = metadata.name;
  }
}

const COMMAND_SCHEMA = {
  title: 'Command metadata schema',
  type: 'object',
  required: [ 'name' ],
  properties: {
    name: {
      description: 'Name of the command',
      type: 'string',
      pattern: '^[A-Z_]{2,32}$'
    },
    description: {
      description: 'Description of the command',
      type: 'string'
    },
    default_hotkeys: {
      description: 'Default hotkeys for the command',
      type: 'object',
      properties: {
        all: {
          description: 'Default hotkeys for all modes',
          type: 'array',
          default: [],
          items: { type: 'string' }
        },
        normal_like: {
          description: 'Default hotkey for normal-like modes',
          type: 'array',
          default: [],
          items: { type: 'string' }
        },
        insert_like: {
          description: 'Default hotkey for insert-like modes',
          type: 'array',
          default: [],
          items: { type: 'string' }
        }
      }
    }
  }
};

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

const MOTION_SCHEMA = {
  title: 'Motion metadata schema',
  type: 'object',
  required: [ 'description' ],
  properties: {
    description: {
      description: 'Description of the motion, shows in HELP menu',
      type: 'string'
    },
    multirow: {
      description: 'Whether the motion is only for multi-row movements',
      type: 'boolean',
      default: false
    }
  }
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

const ACTION_SCHEMA = {
  title: 'Action metadata schema',
  type: 'object',
  required: [ 'description' ],
  properties: {
    description: {
      description: 'Description of the action, shows in HELP menu',
      type: 'string'
    }
  }
};

class KeyDefinitions {
  constructor() {
    // set of possible motions
    this.motion_command_counts = {};
    // set of possible commands for each mode
    this.action_command_counts_by_mode = {};

    this.defaultHotkeys = {};
    // key mappings for normal-like modes (normal, visual, visual-line)
    this.defaultHotkeys[Modes.NORMAL_MODE_TYPE] = {};
    // key mappings for insert-like modes (insert, mark, menu)
    this.defaultHotkeys[Modes.INSERT_MODE_TYPE] = {};

    this.commands = {};
    // nested mapping with command names indexing, leaves are definitions
    this.motions = {};
    // for each mode, nested mapping with command names indexing, leaves are definitions
    this.actions = {};
  }

  // currently used only for testing
  clone() {
    const other = new KeyDefinitions();
    const keys = [
      'motion_command_counts', 'action_command_counts_by_mode',
      'defaultHotkeys',
      'commands', 'motions', 'actions'
    ];
    keys.forEach((key) => {
      other[key] = _.cloneDeep(this[key]);
    });
    return other;
  }

  _add_command(mode, command) {
    // for now, don't list the motion command
    if (command.name !== motionCommandName) {
      if (!this.action_command_counts_by_mode[mode]) {
        this.action_command_counts_by_mode[mode] = {};
      }
      const count = this.action_command_counts_by_mode[mode][command.name] || 0;
      return this.action_command_counts_by_mode[mode][command.name] = count + 1;
    }
  }

  _remove_command(mode, command) {
    // for now, don't list the motion command
    if (command.name !== motionCommandName) {
      if (!this.action_command_counts_by_mode[mode]) {
        this.action_command_counts_by_mode[mode] = {};
      }
      const count = this.action_command_counts_by_mode[mode][command.name] || 0;
      if (count === 0) {
        throw new errors.GenericError(`Cannot remove command ${command}`);
      } else if (count === 1) {
        return delete this.action_command_counts_by_mode[mode][command.name];
      } else {
        return this.action_command_counts_by_mode[mode][command.name] = count - 1;
      }
    }
  }

  _add_motion(command, multirow) {
    const counts = this.motion_command_counts[command.name] || {};
    if (multirow) {
      counts.multirow = (counts.multirow || 0) + 1;
    }
    counts.all = (counts.all || 0) + 1;
    return this.motion_command_counts[command.name] = counts;
  }

  _remove_motion(command, multirow) {
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
      return delete this.motion_command_counts[command.name];
    } else {
      counts.all = (counts.all || 0) - 1;
      return this.motion_command_counts[command.name] = counts;
    }
  }

  get_motions(multirow) {
    const result = [];
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

  commands_for_mode(mode) {
    if (!(mode in this.action_command_counts_by_mode)) {
      return [];
    }
    return Object.keys(this.action_command_counts_by_mode[mode]);
  }

  actions_for_mode(mode) {
    return this.actions[mode] || {};
  }

  registerCommand(metadata) {
    utils.tv4_validate(metadata, COMMAND_SCHEMA, 'command');
    utils.fill_tv4_defaults(metadata, COMMAND_SCHEMA);
    const { name } = metadata;
    const command = new Command(metadata);

    if (command.name in this.commands) {
      throw new errors.GenericError(`Command ${command.name} has already been defined`);
    }

    this.commands[name] = command;
    this.defaultHotkeys[Modes.NORMAL_MODE_TYPE][name] =
      (_.cloneDeep(metadata.default_hotkeys.all)).concat(
        _.cloneDeep(metadata.default_hotkeys.normal_like)
      );
    this.defaultHotkeys[Modes.INSERT_MODE_TYPE][name] =
      (_.cloneDeep(metadata.default_hotkeys.all)).concat(
        _.cloneDeep(metadata.default_hotkeys.insert_like)
      );
    return command;
  }

  deregisterCommand(command) {
    if (!(command.name in this.commands)) {
      throw new errors.GenericError(`Command ${command.name} not found`);
    }
    delete this.commands[command.name];
    delete this.defaultHotkeys[Modes.NORMAL_MODE_TYPE][command.name];
    return delete this.defaultHotkeys[Modes.INSERT_MODE_TYPE][command.name];
  }

  registerMotion(commands, motion, definition) {
    utils.tv4_validate(motion, MOTION_SCHEMA, 'motion');
    utils.fill_tv4_defaults(motion, MOTION_SCHEMA);
    motion.definition = definition;

    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    let obj = this.motions;
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

    command = commands[commands.length-1];

    // motion.name = command.name
    if (command.name in obj) {
      throw new errors.GenericError(`Motion ${command.name} has already been defined`);
    }
    obj[command.name] = motion;
    commands.forEach((cmd) => this._add_motion(cmd, motion.multirow));
    return null;
  }

  deregisterMotion(commands) {
    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    let obj = this.motions;
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

    command = commands[commands.length-1];
    // motion.name = command.name
    if (!(command.name in obj)) {
      throw new errors.GenericError(`Motion ${command.name} not found`);
    }
    const motion = obj[command.name];
    delete obj[command.name];
    commands.forEach((cmd) => this._remove_motion(cmd, motion.multirow));
    return null;
  }

  registerAction(modes, commands, action, definition) {
    utils.tv4_validate(action, ACTION_SCHEMA, 'action');
    action = _.cloneDeep(action);
    action.definition = definition;

    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    modes.forEach((mode) => {
      if (!this.actions[mode]) {
        this.actions[mode] = {};
      }
      let obj = this.actions[mode];

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

      command = commands[commands.length-1];
      // action.name = command.name
      if (command.name in obj) {
        throw new errors.GenericError(`Action ${command.name} has already been defined`);
      }

      obj[command.name] = action;
      commands.forEach((cmd) => this._add_command(mode, cmd));
    });
    return null;
  }

  deregisterAction(modes, commands) {
    if (!commands.slice) {
      // commands isn't an array
      commands = [commands];
    }

    modes.forEach((mode) => {
      if (!this.actions[mode]) {
        this.actions[mode] = {};
      }
      let obj = this.actions[mode];

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

      command = commands[commands.length-1];
      // action.name = command.name
      if (!(command.name in obj)) {
        throw new errors.GenericError(`Action ${command.name} not found`);
      }

      delete obj[command.name];
      commands.forEach((cmd) => this._remove_command(mode, cmd));
    });
    return null;
  }
}

export default new KeyDefinitions();
