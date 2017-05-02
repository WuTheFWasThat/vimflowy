import * as firebase from 'firebase';

import EventEmitter from './eventEmitter';
import * as errors from './errors';
import * as utils from './utils';
import logger from './logger';

import { Row, Line, SerializedPath, MacroMap } from './types';

export type DataSource = 'local' | 'firebase' | 'inmemory';

/*
DataStore abstracts the data layer, so that it can be swapped out.
There are many methods the each type of DataStore should implement to satisfy the API.
However, in the case of a key-value store, one can simply implement `get` and `set` methods.
Currently, DataStore has a synchronous API.  This may need to change eventually...  :(
*/

const timeout = (ns: number) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ns);
  });
};
// const simulateDelay = 10;
// const simulateDelay = 1;
const simulateDelay: number = 0;

const decodeLine: (line: Line) => Line = (line) => line.map((obj: any) => {
  if (typeof obj === 'string') {
    return obj;
  }

  // for backwards compatibility
  return obj.char;
});

// for backwards compatibility, mainly
const decodeParents = (parents: number | Array<number>): Array<number> => {
  if (typeof parents === 'number') {
    parents = [ parents ];
  }
  return parents;
};

export default class DataStore {
  protected prefix: string;
  private docname: string;
  private lastId: number | null;
  private cache: {[key: string]: any};

  constructor(docname = '') {
    this.docname = docname;
    this.prefix = `${docname}save`;
    this.lastId = null;
    this.cache = {};
  }

  private _lastIDKey_() {
    return `${this.prefix}:lastID`;
  }
  private _lineKey_(row: Row): string {
    return `${this.prefix}:${row}:line`;
  }
  private _parentsKey_(row: Row): string {
    return `${this.prefix}:${row}:parent`;
  }
  private _childrenKey_(row: Row): string {
    return `${this.prefix}:${row}:children`;
  }
  private _detachedParentKey_(row: Row): string {
    return `${this.prefix}:${row}:detached_parent`;
  }
  private _collapsedKey_(row: Row): string {
    return `${this.prefix}:${row}:collapsed`;
  }

  private _pluginDataKey_(plugin: string, key: string): string {
    return `${this.prefix}:plugin:${plugin}:data:${key}`;
  }

  // no prefix, meaning it's global
  private _settingKey_(setting: string): string {
    return `settings:${setting}`;
  }

  // not using regular prefix, for backwards compatibility
  private _docSettingKey_(setting: string): string {
    return `settings:${this.docname}:${setting}`;
  }

  private _lastViewrootKey_(): string {
    return `${this.prefix}:lastviewroot2`;
  }
  private _macrosKey_(): string {
    return `${this.prefix}:macros`;
  }

  private async _get<T>(
    key: string,
    default_value: T,
    decode: (value: any) => T = utils.id
  ): Promise<T> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }

    if (key in this.cache) {
      return this.cache[key];
    }
    let value: any = await this.get(key);
    if (value != null) {
      // NOTE: only need try catch for backwards compatibility
      try {
        // need typeof check because of backwards compatibility plus stupidness like
        // JSON.parse([106]) === 106
        if (typeof value === 'string') {
          value = JSON.parse(value);
        }
      } catch (e) {
        // do nothing
      }
    }
    let decodedValue: T;
    if (value === null) {
      decodedValue = default_value;
      logger.debug('tried getting', key, 'defaulted to', decodedValue);
    } else {
      decodedValue = decode(value);
      logger.debug('got from storage', key, decodedValue);
    }
    this.cache[key] = decodedValue;
    return decodedValue;
  }

  protected async get(_key: string): Promise<string | null> {
    throw new errors.NotImplemented();
  }

  private async _set(
    key: string, value: any, encode: (value: any) => any = utils.id
  ): Promise<void> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }

    this.cache[key] = value;
    const encodedValue = encode(value);
    logger.debug('setting to storage', key, encodedValue);
    // NOTE: fire and forget
    this.set(key, JSON.stringify(encodedValue));
  }

  protected async set(
    _key: string, _value: string
  ): Promise<void> {
    throw new errors.NotImplemented();
  }

  // get and set values for a given row
  public async getLine(row: Row): Promise<Line> {
    return await this._get(this._lineKey_(row), [], decodeLine);
  }

  public async setLine(row: Row, line: Line): Promise<void> {
    return await this._set(this._lineKey_(row), line);
  }

  // for backwards compatibility - checks whether the line was struck through
  // in the old-style format
  public async _isStruckThroughOldFormat(row: Row): Promise<boolean> {
    const line = await this._get<any>(this._lineKey_(row), []);
    if (typeof line !== 'string' && line.length) {
      let char_info = line[0];
      if (char_info.properties && char_info.properties.strikethrough) {
        return true;
      }
    }
    return false;
  }

  public async getParents(row: Row): Promise<Array<Row>> {
    return await this._get(this._parentsKey_(row), [], decodeParents);
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

  public async getDetachedParent(row: Row): Promise<Row | null> {
    return await this._get(this._detachedParentKey_(row), null);
  }
  public async setDetachedParent(row: Row, parent: Row | null): Promise<void> {
    return await this._set(this._detachedParentKey_(row), parent);
  }

  public async getCollapsed(row: Row): Promise<boolean> {
    return await this._get(this._collapsedKey_(row), false);
  }
  public async setCollapsed(row: Row, collapsed: boolean): Promise<void> {
    return await this._set(this._collapsedKey_(row), collapsed || false);
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
  // get document specific settings
  public async getDocSetting(
    setting: string, default_value: any = undefined
  ): Promise<any> {
    return await this._get(this._docSettingKey_(setting), default_value);
  }
  public async setDocSetting(setting: string, value: any): Promise<void> {
    return await this._set(this._docSettingKey_(setting), value);
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
  // public so test case can override
  public async getId(): Promise<number> {
    // suggest to override this for efficiency
    let id;
    if (this.lastId === null) {
      id = 1 + await this._get(this._lastIDKey_(), 0);
    } else {
      id = this.lastId + 1;
    }
    // NOTE: fire and forget
    this._set(this._lastIDKey_(), id);
    this.lastId = id;
    return id;
  }

  public async getNew() {
    const id = await this.getId();
    await Promise.all([
      this.setLine(id, []),
      this.setChildren(id, []),
      this.setCollapsed(id, false),
    ]);
    return id;
  }
}

export class InMemory extends DataStore {
  constructor() {
    super('');
  }

  protected async get(_key: string): Promise<string | null> {
    return null;
  }

  protected async set(_key: string, _value: string): Promise<void> {
    // do nothing
  }
}

export class LocalStorageLazy extends DataStore {
  private lastSave: number;
  private trackSaves: boolean;

  protected _lastSaveKey_(): string {
    return `${this.prefix}:lastSave`;
  }

  constructor(docname = '', trackSaves = false) {
    super(docname);
    this.trackSaves = trackSaves;
    if (this.trackSaves) {
      this.lastSave = Date.now();
    }
  }

  protected async get(key: string): Promise<string | null> {
    return this._getLocalStorage_(key);
  }

  protected async set(key: string, value: string): Promise<void> {
    return this._setLocalStorage_(key, value);
  }

  private _setLocalStorage_(
    key: string, value: any,
    options: {doesNotAffectLastSave?: boolean} = {}
  ): void {
    if (this.trackSaves) {
      if (this.getLastSave() > this.lastSave) {
        throw new errors.MultipleUsersError();
      }

      if (!options.doesNotAffectLastSave) {
        this.lastSave = Date.now();
        localStorage.setItem(this._lastSaveKey_(), this.lastSave + '');
      }
    }

    return localStorage.setItem(key, value);
  }

  private _getLocalStorage_(key: string): any | null {
    const val = localStorage.getItem(key);
    if ((val == null) || (val === 'undefined')) {
      return null;
    }
    return val;
  }

  // determine last time saved (for multiple tab detection)
  // note that this doesn't cache!
  public getLastSave(): number {
    return JSON.parse(this._getLocalStorage_(this._lastSaveKey_()) || '0');
  }
}

export class FirebaseStore extends DataStore {
  private fbase: firebase.database.Database;
  private numPendingSaves: number;
  public events: EventEmitter;

  constructor(docname = '', dbName: string, apiKey: string) {
    super(docname);
    this.fbase = firebase.initializeApp({
      apiKey: apiKey,
      databaseURL: `https://${dbName}.firebaseio.com`,
    }).database();

    this.events = new EventEmitter();
    this.numPendingSaves = 0;
    // this.fbase.authWithCustomToken(token, (err, authdata) => {})
  }

  public async init(email: string, password: string) {
    this.events.emit('saved');

    await this.auth(email, password);

    const clientId = Date.now() + '-' + ('' + Math.random()).slice(2);
    const lastClientRef = this.fbase.ref('lastClient');

    await lastClientRef.set(clientId);

    // Number of online users is the number of objects in the presence list.
    lastClientRef.on('value', function(snap) {
      if (snap == null) {
        throw new Error('Failed to get listRef');
      }
      if (snap.val() !== clientId) {
        throw new errors.MultipleUsersError();
      }
    });
  }

  public async auth(email: string, password: string) {
    return await firebase.auth().signInWithEmailAndPassword(email, password);
  }

  protected get(key: string): Promise<string | null> {
    logger.debug('Firebase: getting', key);
    return new Promise((resolve: (result: string | null) => void, reject) => {
      this.fbase.ref(key).once(
        'value',
        (data) => {
          const exists = data.exists();
          if (!exists) {
            return resolve(null);
          }
          return resolve(data.val());
        },
        (err: Error) => {
          return reject(err);
        }
      );
    });
  }

  protected set(key: string, value: string): Promise<void> {
    if (this.numPendingSaves === 0) {
      this.events.emit('unsaved');
    }
    logger.debug('Firebase: setting', key, 'to', value);
    this.numPendingSaves++;
    // TODO: buffer these and batch them?
    this.fbase.ref(key).set(
      value,
      (err) => {
        if (err) { throw err; }
        this.numPendingSaves--;
        if (this.numPendingSaves === 0) {
          this.events.emit('saved');
        }
      }
    );
    return Promise.resolve();
  }
}
