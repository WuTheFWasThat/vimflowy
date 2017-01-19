import * as _ from 'lodash';

import * as errors from './errors';
import logger from './logger';
import EventEmitter from './eventEmitter';
import { KeyDefinitions, Motion, Action, motionKey } from './keyDefinitions';
import KeyMappings, { HotkeyMapping } from './keyMappings';
import { Key } from './types';

// one of these per mode
export class KeyBindingsTree {
  private children: {[key: string]: KeyBindingsTree | Motion | Action};
  public hasMotion: boolean;
  public hasAction: boolean;
  private definitions: KeyDefinitions;
  private lastAdded: [string, Motion | Action] | null;
  private path: Array<Key>; // sequence of keys to get here

  constructor(path: Array<Key>, definitions: KeyDefinitions) {
    this.children = {};
    this.hasMotion = false;
    this.hasAction = false;
    this.lastAdded = null;
    this.path = path;
    this.definitions = definitions;
  }

  public print(tabs = 0) {
    const prefix = ' '.repeat(tabs * 2);
    Object.keys(this.children).forEach((key) => {
      const child: any = this.getKey(key);
      if (child == null) { return; } // this shouldn't happen
      if (child instanceof KeyBindingsTree) {
        console.log(prefix, key, ':'); // tslint:disable-line:no-console
        child.print(tabs + 1);
      } else {
        console.log(prefix, key, ':', child.name); // tslint:disable-line:no-console
      }
    });
  }

  public getKey(key: Key): KeyBindingsTree | Motion | Action | null {
    return this.children[key] || null;
  }

  protected addMappingHelper(
    keys: Array<Key>, index: number, name: string,
    mapped: Action | Motion
  ) {
    const key = keys[index];

    let child = this.children[key];
    if (child instanceof Motion) {
      throw new Error(
        `Multiple registrations for key sequence ${keys.slice(0, index + 1)}:
        ${name} and ${child.name}`
      );
    }
    if (child instanceof Action) {
      throw new Error(
        `Multiple registrations for key sequence ${keys.slice(0, index + 1)}:
        ${name} and ${child.name}`
      );
    }

    if (key === motionKey) {
      if (mapped instanceof Motion) {
        throw new Error('Motions cannot accept motions in bindings');
      } else {
        if (!mapped.metadata.acceptsMotion) {
          throw new Error(`Action ${mapped.name} does not accept motions`);
        }
      }
    }

    if (index === keys.length - 1) {
      if (child != null) {
        throw new errors.GenericError(
          `Multiple registrations for key sequence ${keys.slice(0, index)}:
          ${name} and ${child.lastAdded && child.lastAdded[0]}`
        );
      }

      this.children[key] = mapped;
    } else {
      // need new variable for type safety
      let childBindings: KeyBindingsTree;
      if (child == null) {
        childBindings = new KeyBindingsTree(this.path.concat([key]), this.definitions);
        this.children[key] = childBindings;
      } else {
        childBindings = child;
      }
      childBindings.addMappingHelper(keys, index + 1, name, mapped);
    }

    if (mapped instanceof Motion) {
      this.hasMotion = true;
    } else {
      this.hasAction = true;
    }
    this.lastAdded = [name, mapped];
  }

  public addMapping(name: string, keys: Array<Key>) {
    const mapped = this.definitions.getRegistration(name);
    if (mapped == null) {
      // Ignore mappings if there's no definition
      // This can happen if e.g. we saved keymappings but then turned off a plugin
      logger.warn(`Attempted to register hotkey for ${name}, but no definition found`);
      return;
    }

    this.addMappingHelper(keys, 0, name, mapped);
  }
}

function makeBindings(definitions: KeyDefinitions, mappings: KeyMappings) {
  const allBindings: {[mode: string]: KeyBindingsTree} = {};
  _.map(mappings.mappings, (mapping: HotkeyMapping, mode: string) => {
    const bindings = new KeyBindingsTree([], definitions);
    _.map(mapping, (keySequences: Array<Array<Key>>, command: string) => {
      keySequences.forEach((sequence) => {
        bindings.addMapping(command, sequence);
      });
    });
    allBindings[mode] = bindings;
  });
  return allBindings;
}

export default class KeyBindings extends EventEmitter {
  public bindings: {[mode: string]: KeyBindingsTree};
  public definitions: KeyDefinitions;
  public mappings: KeyMappings;

  private update: () => void;

  constructor(definitions: KeyDefinitions, mappings: KeyMappings) {
    super();
    this.definitions = definitions;

    this.update = () => {
      this.bindings = makeBindings(this.definitions, this.mappings);
      this.emit('update');
    };

    this.definitions.on('update', this.update);
    this.setMappings(mappings);
  }

  public setMappings(mappings: KeyMappings) {
    if (this.mappings) {
      this.mappings.off('update', this.update);
    }
    this.mappings = mappings;
    this.mappings.on('update', this.update);
    this.update();
  }
}
