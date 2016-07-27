/* globals alert, localStorage */

import _ from 'lodash';

import * as errors from './errors';
import * as Logger from './logger';

/*
DataStore abstracts the data layer, so that it can be swapped out.
There are many methods the each type of DataStore should implement to satisfy the API.
However, in the case of a key-value store, one can simply implement `get` and `set` methods.
Currently, DataStore has a synchronous API.  This may need to change eventually...  :(
*/

class DataStore {
  constructor(prefix='') {
    this.prefix = `${prefix}save`;

    this._lineKey_ = function(row) { return `${this.prefix}:${row}:line`; };
    this._parentsKey_ = function(row) { return `${this.prefix}:${row}:parent`; };
    this._childrenKey_ = function(row) { return `${this.prefix}:${row}:children`; };
    this._detachedChildrenKey_ = function(row) { return `${this.prefix}:${row}:detached_children`; };
    this._detachedParentKey_ = function(row) { return `${this.prefix}:${row}:detached_parent`; };
    this._collapsedKey_ = function(row) { return `${this.prefix}:${row}:collapsed`; };

    this._pluginDataKey_ = function(plugin, key) { return `${this.prefix}:plugin:${plugin}:data:${key}`; };

    // no prefix, meaning it's global
    this._settingKey_ = setting => `settings:${setting}`;

    this._lastSaveKey_ = `${this.prefix}:lastSave`;
    this._lastViewrootKey_ = `${this.prefix}:lastviewroot2`;
    this._macrosKey_ = `${this.prefix}:macros`;
    this._IDKey_ = `${this.prefix}:lastID`;
  }

  _get(key, default_value = undefined) {
    console.log('GET key', key, 'default value', default_value);
    throw new errors.NotImplemented();
  }

  _set(key, value) {
    console.log('SET key', key, 'value', value);
    throw new errors.NotImplemented();
  }

  // get and set values for a given row
  getLine(row) {
    return this._get(this._lineKey_(row), []);
  }
  setLine(row, line) {
    return this._set(this._lineKey_(row), line);
  }

  getParents(row) {
    let parents = this._get(this._parentsKey_(row), []);
    if (typeof parents === 'number') {
      parents = [ parents ];
    }
    return parents;
  }
  setParents(row, parents) {
    return this._set(this._parentsKey_(row), parents);
  }

  getChildren(row) {
    return this._get(this._childrenKey_(row), []);
  }
  setChildren(row, children) {
    return this._set(this._childrenKey_(row), children);
  }

  getDetachedParent(row) {
    return this._get(this._detachedParentKey_(row), null);
  }
  setDetachedParent(row, parent) {
    return this._set(this._detachedParentKey_(row), parent);
  }

  getDetachedChildren(row) {
    return this._get(this._detachedChildrenKey_(row), []);
  }
  setDetachedChildren(row, children) {
    return this._set(this._detachedChildrenKey_(row), children);
  }

  getCollapsed(row) {
    return this._get(this._collapsedKey_(row));
  }
  setCollapsed(row, collapsed) {
    return this._set(this._collapsedKey_(row), collapsed);
  }

  // get mapping of macro_key -> macro
  getMacros() {
    return this._get(this._macrosKey_, {});
  }

  // set mapping of macro_key -> macro
  setMacros(macros) {
    return this._set(this._macrosKey_, macros);
  }

  // get global settings (data not specific to a document)
  async getSetting(setting, default_value = undefined) {
    return this._get(this._settingKey_(setting), default_value);
  }
  async setSetting(setting, value) {
    return this._set(this._settingKey_(setting), value);
  }

  // get last view (for page reload)
  setLastViewRoot(ancestry) {
    return this._set(this._lastViewrootKey_, ancestry);
  }
  getLastViewRoot() {
    return this._get(this._lastViewrootKey_, []);
  }

  setPluginData(plugin, key, data) {
    return this._set(this._pluginDataKey_(plugin, key), data);
  }
  getPluginData(plugin, key, default_value = undefined) {
    return this._get(this._pluginDataKey_(plugin, key), default_value);
  }

  // get next row ID
  getId() { // Suggest to override this for efficiency
    let id = 1;
    while (this._get(this._lineKey_(id), null) !== null) {
      id++;
    }
    return id;
  }

  getNew() {
    let id = this.getId();
    this.setLine(id, []);
    this.setChildren(id, []);
    return id;
  }
}

class InMemory extends DataStore {
  constructor() {
    super('');
    this.cache = {};
  }

  _get(key, default_value = undefined) {
    if (key in this.cache) {
      return _.cloneDeep(this.cache[key]);
    } else {
      return default_value;
    }
  }

  _set(key, value) {
    return this.cache[key] = value;
  }
}

class LocalStorageLazy extends DataStore {
  constructor(prefix='') {
    super(prefix);
    this.cache = {};
    this.lastSave = Date.now();
  }

  _get(key, default_value = undefined) {
    if (!(key in this.cache)) {
      this.cache[key] = this._getLocalStorage_(key, default_value);
    }
    return this.cache[key];
  }

  _set(key, value) {
    this.cache[key] = value;
    return this._setLocalStorage_(key, value);
  }

  _setLocalStorage_(key, value, options={}) {
    if (this.getLastSave() > this.lastSave) {
      alert('This document has been modified (in another tab) since opening it in this tab. Please refresh to continue!'
      );
      throw new errors.DataPoisoned('Last save disagrees with cache');
    }

    if (!options.doesNotAffectLastSave) {
      this.lastSave = Date.now();
      localStorage.setItem(this._lastSaveKey_, this.lastSave);
    }

    Logger.logger.debug('setting local storage', key, value);
    return localStorage.setItem(key, JSON.stringify(value));
  }

  _getLocalStorage_(key, default_value = undefined) {
    Logger.logger.debug('getting from local storage', key, default_value);
    let stored = localStorage.getItem(key);
    if (stored === null) {
      Logger.logger.debug('got nothing, defaulting to', default_value);
      return default_value;
    }
    try {
      let val = JSON.parse(stored);
      Logger.logger.debug('got ', val);
      return val;
    } catch (error) {
      Logger.logger.debug('parse failure:', stored);
      return default_value;
    }
  }

  // determine last time saved (for multiple tab detection)
  // doesn't cache!
  getLastSave() {
    return this._getLocalStorage_(this._lastSaveKey_, 0);
  }

  setSchemaVersion(version) {
    return this._setLocalStorage_(this._schemaVersionKey_, version, { doesNotAffectLastSave: true });
  }

  getId() {
    let id = this._getLocalStorage_(this._IDKey_, 1);
    while (this._getLocalStorage_(this._lineKey_(id), null) !== null) {
      id++;
    }
    this._setLocalStorage_(this._IDKey_, (id + 1));
    return id;
  }
}

export { InMemory };
export { LocalStorageLazy };
