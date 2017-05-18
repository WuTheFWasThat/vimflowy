import * as firebase from 'firebase';

import * as errors from '../utils/errors';
import EventEmitter from '../utils/eventEmitter';
import logger from '../utils/logger';

export type BackendType = 'local' | 'firebase' | 'inmemory';

/*
DataBackend abstracts the data layer, so that it can be swapped out.
To implement a new backend, one simply has to implement a simple key-value store
with the two methods get and set.

Note that the backend may want to protect against multiple clients writing/reading.
*/

// NOTE: not very elegant, but this won't collide with other keys
// since prefix always contains either '*save' or 'settings:'.
// Future backends don't need to use this, as long as they prefix the key passed to them.
// Backends can prefix internal usage with internalPrefix to avoid namespace collision.
const internalPrefix: string = 'internal:';

export default class DataBackend {
  public async get(_key: string): Promise<string | null> {
    throw new errors.NotImplemented();
  }

  public async set(
    _key: string, _value: string
  ): Promise<void> {
    throw new errors.NotImplemented();
  }
}

export class InMemory extends DataBackend {
  constructor() {
    super();
  }

  public async get(_key: string): Promise<string | null> {
    return null;
  }

  public async set(_key: string, _value: string): Promise<void> {
    // do nothing
  }
}

export class LocalStorageLazy extends DataBackend {
  private lastSave: number;
  private trackSaves: boolean;
  private docname: string;

  public _lastSaveKey_(): string {
    return `${internalPrefix}${this.docname}:lastSave`;
  }

  constructor(docname = '', trackSaves = false) {
    super();
    this.docname = docname;
    this.trackSaves = trackSaves;
    if (this.trackSaves) {
      this.lastSave = Date.now();
    }
  }

  public async get(key: string): Promise<string | null> {
    return this._getLocalStorage_(key);
  }

  public async set(key: string, value: string): Promise<void> {
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

export class FirebaseBackend extends DataBackend {
  private fbase: firebase.database.Database;
  private numPendingSaves: number;
  private docname: string;
  public events: EventEmitter;

  constructor(docname = '', dbName: string, apiKey: string) {
    super();
    this.docname = docname;
    this.events = new EventEmitter();
    this.fbase = firebase.initializeApp({
      apiKey: apiKey,
      databaseURL: `https://${dbName}.firebaseio.com`,
    }).database();

    this.numPendingSaves = 0;
    // this.fbase.authWithCustomToken(token, (err, authdata) => {})
  }

  public async init(email: string, password: string) {
    this.events.emit('saved');

    await this.auth(email, password);

    const clientId = Date.now() + '-' + ('' + Math.random()).slice(2);
    const lastClientRef = this.fbase.ref(`${internalPrefix}${this.docname}:lastClient`);

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

  public get(key: string): Promise<string | null> {
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

  public set(key: string, value: string): Promise<void> {
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
