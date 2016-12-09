import * as firebase from 'firebase';

import * as _ from 'lodash';

import EventEmitter from './eventEmitter';
import * as constants from './constants';
import * as errors from './errors';
import logger from './logger';

import { Line, Row, SerializedPath, MacroMap } from './types';

export type DataSource = 'local' | 'firebase' | 'inmemory';

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

const encodeLine = (line) => line.map((obj) => {
  // if no properties are true, serialize just the character to save space
  if (_.every(constants.text_properties.map(property => !obj[property]))) {
    return obj.char;
  } else {
    return obj;
  }
});

const decodeLine = (line) => line.map((obj) => {
  if (typeof obj === 'string') {
    obj = { char: obj };
  }
  return obj;
});

// for reverse compatibility, mainly
const decodeParents = (parents) => {
  if (typeof parents === 'number') {
    parents = [ parents ];
  }
  return parents;
};

const identity = (x) => x;

export default class DataStore {
  protected prefix: string;
  private lastId: number | null;
  private cache: {[key: string]: any};

  constructor(prefix = '') {
    this.prefix = `${prefix}save`;
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
  private _detachedChildrenKey_(row: Row): string {
    return `${this.prefix}:${row}:detached_children`;
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
  private _settingKey_(setting): string {
    return `settings:${setting}`;
  }

  private _lastViewrootKey_(): string {
    return `${this.prefix}:lastviewroot2`;
  }
  private _macrosKey_(): string {
    return `${this.prefix}:macros`;
  }

  private async _get(
    key: string, default_value: any = undefined, decode: (value: any) => any = identity
  ): Promise<any | null> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }

    if (key in this.cache) {
      return this.cache[key];
    }
    const value = await this.get(key);
    let decodedValue;
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

  protected async get(key: string): Promise<any> {
    throw new errors.NotImplemented();
  }

  private async _set(
    key: string, value: any, encode: (value: any) => any = identity
  ): Promise<void> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }

    const encodedValue = encode(value);
    logger.debug('setting to storage', key, encodedValue);
    this.cache[key] = encodedValue;
    this.set(key, encodedValue);
  }

  protected async set(
    key: string, value: any
  ): Promise<void> {
    throw new errors.NotImplemented();
  }

  // get and set values for a given row
  public async getLine(row: Row): Promise<Line> {
    return await this._get(this._lineKey_(row), [], decodeLine);
  }

  public async setLine(row: Row, line: Line): Promise<void> {
    return await this._set(this._lineKey_(row), line, encodeLine);
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

  public async getDetachedParent(row: Row): Promise<Row> {
    return await this._get(this._detachedParentKey_(row), null);
  }
  public async setDetachedParent(row: Row, parent: Row | null): Promise<void> {
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

  protected async get(key: string): Promise<any | null> {
    return null;
  }

  protected async set(key: string, value: any): Promise<void> {
    // do nothing
  }
}

export class LocalStorageLazy extends DataStore {
  private lastSave: number;
  private trackSaves: boolean;

  protected _lastSaveKey_(): string {
    return `${this.prefix}:lastSave`;
  }

  constructor(prefix = '', trackSaves = false) {
    super(prefix);
    this.trackSaves = trackSaves;
    if (this.trackSaves) {
      this.lastSave = Date.now();
    }
  }

  protected async get(key: string): Promise<any | null> {
    return this._getLocalStorage_(key);
  }

  protected async set(key: string, value: any): Promise<void> {
    return this._setLocalStorage_(key, value);
  }

  private _setLocalStorage_(
    key: string, value: any,
    options: {doesNotAffectLastSave?: boolean} = {}
  ): void {
    if (this.trackSaves) {
      if (this.getLastSave() > this.lastSave) {
        throw new errors.MultipleUsersError(
          'This document has been modified (in another tab) since opening it in this tab. Please refresh to continue!'
        );
      }

      if (!options.doesNotAffectLastSave) {
        this.lastSave = Date.now();
        localStorage.setItem(this._lastSaveKey_(), this.lastSave + '');
      }
    }

    return localStorage.setItem(key, JSON.stringify(value));
  }

  private _getLocalStorage_(key: string): any | null {
    const val = localStorage.getItem(key);
    if ((val == null) || (val === 'undefined')) {
      return null;
    }
    return JSON.parse(val);
  }

  // determine last time saved (for multiple tab detection)
  // note that this doesn't cache!
  public getLastSave(): number {
    return this._getLocalStorage_(this._lastSaveKey_()) || 0;
  }
}

export class FirebaseStore extends DataStore {
  private fbase: any;
  // private fbase: Firebase;
  private numPendingSaves: number;
  public events: EventEmitter;

  constructor(prefix = '', dbName, apiKey) {
    super(prefix);
    this.fbase = firebase.initializeApp({
      apiKey: apiKey,
      databaseURL: `https://${dbName}.firebaseio.com`,
    }).database();

    this.events = new EventEmitter();
    this.numPendingSaves = 0;
    // this.fbase.authWithCustomToken(token, (err, authdata) => {})
  }

  public async init(email, password) {
    this.events.emit('saved');

    await this.auth(email, password);

    const listRef = this.fbase.ref('presence');
    const userRef = listRef.push();
    const initTime = Date.now();

    await new Promise((resolve) => {
      this.fbase.ref('.info/connected').on('value', function(snap) {
        if (snap.val()) {
          // Remove ourselves when we disconnect.
          userRef.onDisconnect().remove();

          userRef.set(initTime);
          resolve();
        }
      });
    });

    // Number of online users is the number of objects in the presence list.
    listRef.on('value', function(snap) {
      const numUsers = snap.numChildren();
      logger.info(`${numUsers} users online`);
      if (numUsers > 1) {
        snap.forEach((x) => {
          if (x.val() > initTime) {
            throw new errors.MultipleUsersError(
              'This document has been modified (in another tab) since opening it in this tab. Please refresh to continue!'
            );
          }
        });
      }
    });
  }

  public async auth(email, password) {
    return await firebase.auth().signInWithEmailAndPassword(email, password);
  }

  protected get(key: string): Promise<any | null> {
    return new Promise((resolve: (result: any | null) => void, reject) => {
      this.fbase.ref(key).once(
        'value',
        (data) => {
          const exists = data.exists();
          if (!exists) {
            return resolve(null);
          }
          return resolve(data.val());
        },
        (err) => {
          return reject(err);
        }
      );
    });
  }

  protected set(key: string, value: any): Promise<void> {
    if (this.numPendingSaves === 0) {
      this.events.emit('unsaved');
    }
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
