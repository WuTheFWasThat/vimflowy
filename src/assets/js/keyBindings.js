// imports
import _ from 'lodash';

// import * as utils from './utils';
import * as Modes from './modes';
import * as errors from './errors';
import logger from './logger';
import EventEmitter from './eventEmitter';

/*
Terminology:
      key       - a key corresponds to a keypress, including modifiers/special keys
      command   - a command is a semantic event (see keyDefinitions.js)
      mode      - same as vim's notion of modes.
                  each mode determines the set of possible commands, and a new set of bindings
      mode type - there are two mode types: insert-like and normal-like.
                  Each mode falls into precisely one of these two categories.
                  'insert-like' describes modes in which typing characters inserts the characters.
                  Thus the only keys configurable as commands are those with modifiers.
                  'normal-like' describes modes in which the user is not typing, and all keys are potential commands.

The Keybindings class is primarily responsible for dealing with hotkeys
Given a hotkey mapping, it combines it with key definitions to create a bindings dictionary,
also performing some validation on the hotkeys.
Concretely, it exposes 2 main objects:
      hotkeys:
          a 2-layered mapping.  For each mode type and command name, contains a list of keys
          this is the object the user can configure
      bindings:
          another 2-layer mapping.  For each mode and relevant key, maps to the corresponding command's function
          this is the object used internally for handling keys (i.e. translating them to commands)
It also internally maintains
      keyMaps:
          a 2-layer mapping similar to hotkeys.  For each mode and command name, a list of keys.
          Used for rendering the hotkeys table
          besides translating the mode types into each mode,
          keyMaps differs from hotkeys by handles some quirky behavior,
          such as making the DELETE_CHAR command always act like DELETE in visual/visual_line modes

*/

// TODO: merge this into keyDefinitions

const MODES = Modes.modes;
const MODE_TYPES = Modes.types;

export default class KeyBindings extends EventEmitter {
  // takes key definitions and keyMappings, and combines them to key bindings
  getBindings(definitions, keyMap) {
    const bindings = {};
    for (const name in definitions) {
      let keys;
      if (name === 'MOTION') {
        keys = ['MOTION'];
      } else if (name in keyMap) {
        keys = keyMap[name];
      } else {
        continue;
      }

      const v = _.cloneDeep(definitions[name]);
      v.name = name;

      if (typeof v.definition === 'object') {
        const [err, sub_bindings] = this.getBindings(v.definition, keyMap);
        if (err) {
          return [err, null];
        } else {
          v.definition = sub_bindings;
        }
      }

      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        if (key in bindings) {
          return [`Duplicate binding on key ${key}`, bindings];
        }
        bindings[key] = v;
      }
    }
    return [null, bindings];
  }

  constructor(definitions, hotkey_settings) {
    super();

    this.definitions = definitions;
    // a mapping from commands to keys
    this.keyMaps = null;
    // a recursive mapping from keys to commands
    this.bindings = null;

    this.hotkey_settings = null;
    const err = this.apply_hotkey_settings(hotkey_settings);

    if (err) {
      logger.error(`Failed to apply desired hotkeys ${hotkey_settings}`);
      logger.error(err);
      this.apply_default_hotkey_settings();
    }
  }

  // tries to apply new hotkey settings, returning an error if there was one
  // new bindings may result if any of the following happen:
  //   - hotkey settings change
  //   - mode registered/deregistered
  //   - command, motion, or action registered/deregistered
  apply_hotkey_settings(hotkey_settings = {}) {
    // merge hotkey settings into default hotkeys (in case default hotkeys has some new things)
    const hotkeys = {};
    for (const mode_type in MODE_TYPES) {
      hotkeys[mode_type] = _.extend({}, this.definitions.defaultHotkeys[mode_type], hotkey_settings[mode_type] || {});
    }

    // for each mode, get key mapping for that particular mode - a mapping from command to set of keys
    const keyMaps = {};
    for (const mode_type in MODE_TYPES) {
      const mode_type_obj = MODE_TYPES[mode_type];
      for (let i = 0; i < mode_type_obj.modes.length; i++) {
        const mode = mode_type_obj.modes[i];
        const modeKeyMap = {};
        this.definitions.commands_for_mode(mode).forEach((command) => {
          modeKeyMap[command] = hotkeys[mode_type][command].slice();
        });

        this.definitions.get_motions(!Modes.getMode(mode).within_row).forEach((command) => {
          modeKeyMap[command] = hotkeys[mode_type][command].slice();
        });

        keyMaps[mode] = modeKeyMap;
      }
    }

    const bindings = {};
    for (const mode_name in MODES) {
      const mode = MODES[mode_name];
      const [err, mode_bindings] = this.getBindings(this.definitions.actions_for_mode(mode), keyMaps[mode]);
      if (err) { return `Error getting bindings for ${mode_name}: ${err}`; }
      bindings[mode] = mode_bindings;
    }

    const motion_bindings = {};
    for (const mode_name in MODES) {
      const mode = MODES[mode_name];
      const [err, mode_bindings] = this.getBindings(this.definitions.motions, keyMaps[mode]);
      if (err) { return `Error getting motion bindings for ${mode_name}: ${err}`; }
      motion_bindings[mode] = mode_bindings;
    }

    this.hotkeys = hotkeys;
    this.bindings = bindings;
    this.motion_bindings = motion_bindings;
    this.keyMaps = keyMaps;

    this.hotkey_settings = hotkey_settings;
    this.emit('applied_hotkey_settings', hotkey_settings);
    return null;
  }

  // apply default hotkeys
  apply_default_hotkey_settings() {
    const err = this.apply_hotkey_settings({});
    return errors.assert_equals(err, null, 'Failed to apply default hotkeys');
  }

  reapply_hotkey_settings() {
    const err = this.apply_hotkey_settings(this.hotkey_settings);
    return err;
  }
}

  // TODO getBindings: (mode) -> return @bindings[mode]
