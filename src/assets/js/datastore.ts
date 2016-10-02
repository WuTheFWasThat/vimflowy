/* globals alert, localStorage */

import * as _ from 'lodash';

import * as constants from './constants';
import * as errors from './errors';
import logger from './logger';

import { Line, Row, SerializedPath, MacroMap } from './types';

/*
DataStore abstracts the data layer, so that it can be swapped out.
There are many methods the each type of DataStore should implement to satisfy the API.
However, in the case of a key-value store, one can simply implement `get` and `set` methods.
Currently, DataStore has a synchronous API.  This may need to change eventually...  :(
*/

const timeout = (ns) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ns);
  });
};
// const simulateDelay = 10;
// const simulateDelay = 1;
const simulateDelay = 0;

export default class DataStore {
  protected prefix: string;

  constructor(prefix = '') {
    this.prefix = `${prefix}save`;
  }

  protected _lineKey_(row: Row): string {
    return `${this.prefix}:${row}:line`;
  }
  protected _parentsKey_(row: Row): string {
    return `${this.prefix}:${row}:parent`;
  }
  protected _childrenKey_(row: Row): string {
    return `${this.prefix}:${row}:children`;
  }
  protected _detachedChildrenKey_(row: Row): string {
    return `${this.prefix}:${row}:detached_children`;
  }
  protected _detachedParentKey_(row: Row): string {
    return `${this.prefix}:${row}:detached_parent`;
  }
  protected _collapsedKey_(row: Row): string {
    return `${this.prefix}:${row}:collapsed`;
  }

  protected _pluginDataKey_(plugin: string, key: string): string {
    return `${this.prefix}:plugin:${plugin}:data:${key}`;
  }

  // no prefix, meaning it's global
  protected _settingKey_(setting): string {
    return `settings:${setting}`;
  }

  protected _lastSaveKey_(): string {
    return `${this.prefix}:lastSave`;
  }
  protected _lastViewrootKey_(): string {
    return `${this.prefix}:lastviewroot2`;
  }
  protected _macrosKey_(): string {
    return `${this.prefix}:macros`;
  }

  protected async _get(key: string, default_value: any = undefined): Promise<any> {
    console.log('GET key', key, 'default value', default_value);
    throw new errors.NotImplemented();
  }

  protected async _set(key: string, value: any): Promise<void> {
    console.log('SET key', key, 'value', value);
    throw new errors.NotImplemented();
  }

  // get and set values for a given row
  public async getLine(row: Row): Promise<Line> {
    return (await this._get(this._lineKey_(row), [])).map(function(obj) {
      if (typeof obj === 'string') {
        obj = {
          char: obj,
        };
      }
      return obj;
    });
  }
  public async setLine(row: Row, line: Line): Promise<void> {
    return await this._set(this._lineKey_(row), line.map(function(obj) {
      // if no properties are true, serialize just the character to save space
      if (_.every(constants.text_properties.map(property => !obj[property]))) {
        return obj.char;
      } else {
        return obj;
      }
    }));
  }

  public async getParents(row: Row): Promise<Array<Row>> {
    let parents = await this._get(this._parentsKey_(row), []);
    if (typeof parents === 'number') {
      parents = [ parents ];
    }
    return parents;
  }
  public async setParents(row: Row, parents: Array<Row>): Promise<void> {
    return await this._set(this._parentsKey_(row), parents);
  }

  public async getChildren(row: Row): Promise<Array<Row>> {
    return await this._get(this._childrenKey_(row), []);
  }
  public async setChildren(row: Row, children: Array<Row>): Promise<void> {
    return await this._set(this._childrenKey_(row), children);
  }

  public async getDetachedParent(row: Row): Promise<Row> {
    return await this._get(this._detachedParentKey_(row), null);
  }
  public async setDetachedParent(row: Row, parent: Row): Promise<void> {
    return await this._set(this._detachedParentKey_(row), parent);
  }

  public async getDetachedChildren(row: Row): Promise<Array<Row>> {
    return await this._get(this._detachedChildrenKey_(row), []);
  }
  public async setDetachedChildren(row: Row, children: Array<Row>): Promise<void> {
    return await this._set(this._detachedChildrenKey_(row), children);
  }

  public async getCollapsed(row: Row): Promise<boolean> {
    return await this._get(this._collapsedKey_(row));
  }
  public async setCollapsed(row: Row, collapsed: boolean): Promise<void> {
    return await this._set(this._collapsedKey_(row), collapsed);
  }

  // get mapping of macro_key -> macro
  public async getMacros(): Promise<MacroMap> {
    return await this._get(this._macrosKey_(), {});
  }

  // set mapping of macro_key -> macro
  public async setMacros(macros: MacroMap): Promise<void> {
    return await this._set(this._macrosKey_(), macros);
  }

  // get global settings (data not specific to a document)
  public async getSetting(
    setting: string, default_value: any = undefined
  ): Promise<any> {
    return await this._get(this._settingKey_(setting), default_value);
  }
  public async setSetting(setting: string, value: any): Promise<void> {
    return await this._set(this._settingKey_(setting), value);
  }

  // get last view (for page reload)
  public async setLastViewRoot(ancestry: SerializedPath): Promise<void> {
    await this._set(this._lastViewrootKey_(), ancestry);
  }
  public async getLastViewRoot(): Promise<SerializedPath> {
    return await this._get(this._lastViewrootKey_(), []);
  }

  public async setPluginData(
    plugin: string, key: string, data: any
  ): Promise<void> {
    await this._set(this._pluginDataKey_(plugin, key), data);
  }
  public async getPluginData(
    plugin: string, key: string, default_value: any = undefined
  ): Promise<any> {
    return await this._get(this._pluginDataKey_(plugin, key), default_value);
  }

  // get next row ID
  protected async getId(): Promise<number> {
    // suggest to override this for efficiency
    let id = 1;
    while ((await this._get(this._lineKey_(id), null)) !== null) {
      id++;
    }
    return id;
  }

  public async getNew() {
    const id = await this.getId();
    await this.setLine(id, []);
    this.setChildren(id, []);
    return id;
  }
}

export class InMemory extends DataStore {
  private cache: {[key: string]: string};

  constructor() {
    super('');
    this.cache = {};
  }

  protected async _get(key: string, default_value: any = undefined): Promise<any> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }
    if (key in this.cache) {
      return _.cloneDeep(this.cache[key]);
    } else {
      return default_value;
    }
  }

  protected async _set(key: string, value: any): Promise<void> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }
    this.cache[key] = value;
  }
}

export class LocalStorageLazy extends DataStore {
  private cache: {[key: string]: any};
  private lastSave: number;

  constructor(prefix = '') {
    super(prefix);
    this.cache = {};
    this.lastSave = Date.now();
  }

  private _IDKey_() {
    return `${this.prefix}:lastID`;
  }

  protected async _get(key: string, default_value: any = undefined): Promise<any> {
    if (!(key in this.cache)) {
      this.cache[key] = this._getLocalStorage_(key, default_value);
    }
    return this.cache[key];
  }

  protected async _set(key: string, value: any): Promise<void> {
    this.cache[key] = value;
    return this._setLocalStorage_(key, value);
  }

  private _setLocalStorage_(
    key: string, value: any,
    options: {doesNotAffectLastSave?: boolean} = {}
  ): void {
    if (this.getLastSave() > this.lastSave) {
      alert('This document has been modified (in another tab) since opening it in this tab. Please refresh to continue!'
      );
      throw new errors.DataPoisoned('Last save disagrees with cache');
    }

    if (!options.doesNotAffectLastSave) {
      this.lastSave = Date.now();
      localStorage.setItem(this._lastSaveKey_(), this.lastSave + '');
    }

    logger.debug('setting local storage', key, value);
    return localStorage.setItem(key, JSON.stringify(value));
  }

  private _getLocalStorage_(key: string, default_value: any = undefined): any {
    logger.debug('getting from local storage', key, default_value);
    const stored = localStorage.getItem(key);
    if (stored === null) {
      logger.debug('got nothing, defaulting to', default_value);
      return default_value;
    }
    try {
      const val = JSON.parse(stored);
      logger.debug('got ', val);
      return val;
    } catch (error) {
      logger.debug('parse failure:', stored);
      return default_value;
    }
  }

  // determine last time saved (for multiple tab detection)
  // doesn't cache!
  public getLastSave(): number {
    return this._getLocalStorage_(this._lastSaveKey_(), 0);
  }

  protected async getId(): Promise<number> {
    let id: number = this._getLocalStorage_(this._IDKey_(), 1);
    while (this._getLocalStorage_(this._lineKey_(id), null) !== null) {
      id++;
    }
    this._setLocalStorage_(this._IDKey_(), id + 1);
    return id;
  }
}
