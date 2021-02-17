import * as errors from './utils/errors';

/*
DataBackend abstracts the data layer, so that it can be swapped out.
To implement a new backend, one simply has to implement a simple key-value store
with the two methods get and set.

Note that the backend may want to protect against multiple clients writing/reading.
*/

export default class DataBackend {
  public async get(_key: string): Promise<string | null> {
    throw new errors.NotImplemented();
  }

  public async set(_key: string, _value: string): Promise<void> {
    throw new errors.NotImplemented();
  }
}

export class SynchronousDataBackend {
  public get(_key: string): string | null {
    throw new errors.NotImplemented();
  }

  public set(_key: string, _value: string): void {
    throw new errors.NotImplemented();
  }
}

export class SynchronousInMemory extends SynchronousDataBackend {
  private cache: {[key: string]: any} = {};
  // constructor() {
  //   super();
  // }

  public get(key: string): string | null {
    if (key in this.cache) {
      return this.cache[key];
    }
    return null;
  }

  public set(key: string, value: string): void {
    this.cache[key] = value;
  }
}

export class InMemory extends DataBackend {
  private sync_backend: SynchronousInMemory;
  constructor() {
    super();
    this.sync_backend = new SynchronousInMemory();
  }

  public async get(key: string): Promise<string | null> {
    return this.sync_backend.get(key);
  }

  public async set(key: string, value: string): Promise<void> {
    this.sync_backend.set(key, value);
  }
}

