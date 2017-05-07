import * as _ from 'lodash';

import EventEmitter from './utils/eventEmitter';
import logger from './utils/logger';
import { Key } from './types';

export type HotkeyMapping = {
  [name: string]: Array<Array<Key>>
};

export type HotkeyMappingPerMode = {[mode: string]: HotkeyMapping};

// for each mode, keeps a set of hotkeys
// simple wrapper class, no sanity checks
export default class KeyMappings extends EventEmitter {
  public mappings: HotkeyMappingPerMode;

  public static merge(first: KeyMappings, second: KeyMappings) {
    const getMerged = () => {
      const mappings = _.cloneDeep(first.mappings);
      Object.keys(second.mappings).forEach((mode) => {
        mappings[mode] = Object.assign(mappings[mode] || {}, second.mappings[mode]);
      });
      return mappings;
    };
    const merged = new KeyMappings(getMerged());

    first.on('update', () => merged.setMappings(getMerged()));
    second.on('update', () => merged.setMappings(getMerged()));
    return merged;
  }

  constructor(mappings: HotkeyMappingPerMode) {
    super();
    this.mappings = _.cloneDeep(mappings);
  }

  public setMappings(mappings: HotkeyMappingPerMode) {
    this.mappings = mappings;
    this.emit('update');
  }

  public serialize() {
    return _.cloneDeep(this.mappings);
  }

  private _registerMapping(mode: string, keySequence: Array<Key>, name: string) {
    let mappings_for_mode = this.mappings[mode];
    if (!mappings_for_mode) {
      mappings_for_mode = {};
      this.mappings[mode] = mappings_for_mode;
    }
    let sequences_for_name = mappings_for_mode[name];
    if (!sequences_for_name) {
      sequences_for_name = [];
      mappings_for_mode[name] = sequences_for_name;
    }
    sequences_for_name.push(keySequence);
  }

  public registerMapping(mode: string, keySequence: Array<Key>, name: string) {
    this._registerMapping(mode, keySequence, name);
    this.emit('update');
  }

  public registerModeMappings(mode: string, mappings: HotkeyMapping) {
    Object.keys(mappings).forEach((name) => {
      const keySequences = mappings[name];
      keySequences.forEach((sequence) => this._registerMapping(mode, sequence, name));
    });
    this.emit('update');
  }

  // TODO: future dont require name for this
  // also sanity check collisions in registration
  private _deregisterMapping(mode: string, keySequence: Array<Key>, name: string) {
    const mappings_for_mode = this.mappings[mode];
    if (!mappings_for_mode) {
      logger.warn(`Nothing to deregister for mode ${mode}`);
      return;
    }
    let sequences_for_name = mappings_for_mode[name];
    if (!(sequences_for_name && sequences_for_name.length)) {
      logger.warn(`No sequences to deregister for ${name} in mode ${mode}`);
      return;
    }
    sequences_for_name = sequences_for_name.filter((sequence) => {
      return JSON.stringify(sequence) !== JSON.stringify(keySequence);
    });
    mappings_for_mode[name] = sequences_for_name;
  }

  public deregisterMapping(mode: string, keySequence: Array<Key>, name: string) {
    this._deregisterMapping(mode, keySequence, name);
    this.emit('update');
  }

  public deregisterModeMappings(mode: string, mappings: HotkeyMapping) {
    Object.keys(mappings).forEach((name) => {
      const keySequences = mappings[name];
      keySequences.forEach((sequence) => this._deregisterMapping(mode, sequence, name));
    });
    this.emit('update');
  }
}
