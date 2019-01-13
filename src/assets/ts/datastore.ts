import EventEmitter from './utils/eventEmitter';
import * as fn_utils from './utils/functional';
import logger from '../../shared/utils/logger';
import DataBackend, { SynchronousDataBackend } from '../../shared/data_backend';
import * as ClientDataBackends from './data_backend';
import { Theme, defaultTheme } from './themes';

import { Row, Line, SerializedPath, MacroMap } from './types';

/*
DataStore abstracts the data layer, so that it can be swapped out.
There are many methods the each type of DataStore should implement to satisfy the API.
However, in the case of a key-value store, one can simply implement `get` and `set` methods.
Currently, DataStore has a synchronous API.  This may need to change eventually...  :(
*/

// TODO: think this through more clearly.  for server case, we may want controlled behavior of how documents are stored
// ClientSettings: settings specific to a client (stored locally, not per document)
// LocalDocSettings: settings specific to a client and document name (stored locally, per document)
// DocSettings: settings specific to a document (stored remotely, per document)

// TODO: plugin enabling should get to choose if local or remote

export type ClientSettings = Theme & {
  showKeyBindings: boolean;
  hotkeys: any; // TODO
  copyToClipboard: boolean;
};

type ClientSetting = keyof ClientSettings;

const default_client_settings: ClientSettings =
  Object.assign({}, defaultTheme, {
    showKeyBindings: true,
    hotkeys: {},
    copyToClipboard: true,
  });

export type LocalDocSettings = {
  dataSource: ClientDataBackends.BackendType;
  firebaseId: string | null;
  firebaseApiKey: string | null;
  firebaseUserEmail: string | null;
  firebaseUserPassword: string | null;
  socketServerHost: string | null;
  socketServerPassword: string | null;
  socketServerDocument: string | null,
};

type LocalDocSetting = keyof LocalDocSettings;

const default_local_doc_settings: LocalDocSettings = {
  dataSource: 'local',
  firebaseId: null,
  firebaseApiKey: null,
  firebaseUserEmail: null,
  firebaseUserPassword: null,
  socketServerHost: null,
  socketServerPassword: null,
  socketServerDocument: null,
};

export class ClientStore {
  private prefix: string;
  private docname: string;
  private backend: SynchronousDataBackend;
  private cache: {[key: string]: any} = {};
  private use_cache: boolean = true;

  constructor(backend: SynchronousDataBackend, docname = '') {
    this.backend = backend;
    this.docname = docname;
    this.prefix = `${docname}save`;
  }

  private _get<T>(key: string, default_value: T): T {
    if (this.use_cache) {
      if (key in this.cache) {
        return this.cache[key];
      }
    }
    let value: any = this.backend.get(key);
    try {
      value = JSON.parse(value);
    } catch (e) { /* do nothing - this shouldn't happen */ }
    if (value === null) {
      value = default_value;
      logger.debug('tried getting', key, 'defaulted to', default_value);
    } else {
      logger.debug('got from storage', key, value);
    }
    if (this.use_cache) {
      this.cache[key] = value;
    }
    return value;
  }

  private _set(key: string, value: any): void {
    if (this.use_cache) {
      this.cache[key] = value;
    }
    logger.debug('setting to storage', key, value);
    this.backend.set(key, JSON.stringify(value));
  }

  // TODO: also have local pluginData

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

  // get mapping of macro_key -> macro
  public getMacros(): MacroMap {
    return this._get(this._macrosKey_(), {});
  }

  // set mapping of macro_key -> macro
  public setMacros(macros: MacroMap) {
    this._set(this._macrosKey_(), macros);
  }

  public getClientSetting<S extends ClientSetting>(setting: S): ClientSettings[S] {
    return this._get(this._settingKey_(setting), default_client_settings[setting]);
  }

  public setClientSetting<S extends ClientSetting>(setting: S, value: ClientSettings[S]) {
    this._set(this._settingKey_(setting), value);
  }

  public getDocSetting<S extends LocalDocSetting>(setting: S): LocalDocSettings[S] {
    const default_value = default_local_doc_settings[setting];
    return this._get(this._docSettingKey_(setting), default_value);
  }

  public setDocSetting<S extends LocalDocSetting>(setting: S, value: LocalDocSettings[S]) {
    this._set(this._docSettingKey_(setting), value);
  }

  // get last view (for page reload)
  public setLastViewRoot(ancestry: SerializedPath) {
    this._set(this._lastViewrootKey_(), ancestry);
  }
  public getLastViewRoot(): SerializedPath {
    return this._get(this._lastViewrootKey_(), []);
  }
}

export type DocSettings = {
  enabledPlugins: Array<string>,
};

type DocSetting = keyof DocSettings;

const default_doc_settings: DocSettings = {
  // TODO import these names from the plugins
  enabledPlugins: ['Marks', 'HTML', 'LaTeX', 'Text Formatting', 'Todo'],
};

const timeout = (ns: number) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ns);
  });
};
// const simulateDelay = 10;
// const simulateDelay = 1;
const simulateDelay: number = 0;

const decodeLine: (line: Line) => Line = (line: any) => {
  if (typeof line === 'string') {
    return line.split('');
  }
  return line.map((obj: any) => {
    if (typeof obj === 'string') {
      return obj;
    }

    // for backwards compatibility
    return obj.char;
  });
};

const encodeLine: (line: Line) => string = (line) => line.join('');

// for backwards compatibility, mainly
const decodeParents = (parents: number | Array<number>): Array<number> => {
  if (typeof parents === 'number') {
    parents = [ parents ];
  }
  return parents;
};

export class DocumentStore {
  private lastId: number | null;
  private prefix: string;
  private docname: string;
  private cache: {[key: string]: any} = {};
  private use_cache: boolean = true;
  public events: EventEmitter = new EventEmitter();
  private backend: DataBackend;

  constructor(backend: DataBackend, docname = '') {
    this.backend = backend;
    this.docname = docname;
    this.prefix = `${this.docname}save`;
    this.lastId = null;
  }

  private async _get<T>(
    key: string,
    default_value: T,
    decode: (value: any) => T = fn_utils.id
  ): Promise<T> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }

    if (this.use_cache) {
      if (key in this.cache) {
        return this.cache[key];
      }
    }
    let value: any = await this.backend.get(key);
    try {
      // need typeof check because of backwards compatibility plus stupidness like
      // JSON.parse([106]) === 106
      if (typeof value === 'string') {
        value = JSON.parse(value);
      }
    } catch (e) { /* do nothing - this should only happen for historical reasons */ }
    let decodedValue: T;
    if (value === null) {
      decodedValue = default_value;
      logger.debug('tried getting', key, 'defaulted to', decodedValue);
    } else {
      decodedValue = decode(value);
      logger.debug('got from storage', key, decodedValue);
    }
    if (this.use_cache) {
      this.cache[key] = decodedValue;
    }
    return decodedValue;
  }

  private async _set(
    key: string, value: any, encode: (value: any) => any = fn_utils.id
  ): Promise<void> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }

    if (this.use_cache) {
      this.cache[key] = value;
    }
    const encodedValue = encode(value);
    logger.debug('setting to storage', key, encodedValue);
    // NOTE: fire and forget
    this.backend.set(key, JSON.stringify(encodedValue)).catch((err) => {
      setTimeout(() => { throw err; });
    });
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

  private _settingKey_(setting: string): string {
    return `${this.prefix}:settings:${setting}`;
  }

  // get and set values for a given row
  public async getLine(row: Row): Promise<Line> {
    return await this._get(this._lineKey_(row), [], decodeLine);
  }

  public async setLine(row: Row, line: Line): Promise<void> {
    return await this._set(this._lineKey_(row), line, encodeLine);
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

  public async getSetting<S extends DocSetting>(setting: S): Promise<DocSettings[S]> {
    const default_value = default_doc_settings[setting];
    return await this._get(this._settingKey_(setting), default_value);
  }

  public async setSetting<S extends DocSetting>(setting: S, value: DocSettings[S]): Promise<void> {
    return await this._set(this._settingKey_(setting), value);
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
