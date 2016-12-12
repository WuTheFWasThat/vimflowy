// based on https://gist.github.com/contra/2759355

// TODO: split eventEmitter and hooks into separate classes
// TODO: get rid of all the anys in this file.  use new typescript feature, like
// export default class EventEmitter<LTypes> {
//   private listeners: {[K in keyof LTypes]: Array<(...args: LTypes[K]) => any>};
//

export type Listener = (...args: any[]) => any;
export type Hook = (obj: any, info: any) => any;

export default class EventEmitter {
  private listeners: {[key: string]: Array<Listener>};
  private hooks: {[key: string]: Array<Hook>};

  constructor() {
    // mapping from event to list of listeners
    this.listeners = {};
    this.hooks = {};
  }

  // emit an event and return all responses from the listeners
  public emit(event: string, ...args: Array<any>) {
    return (this.listeners[event] || []).map((listener) => {
      return listener.apply(listener, args);
    });
  }

  public emitAsync(event: string, ...args: Array<any>) {
    return Promise.all((this.listeners[event] || []).map(async (listener) => {
      return await listener.apply(listener, args);
    }));
  }

  public addListener(event: string, listener: Listener) {
    this.emit('newListener', event, listener);
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(listener);
    return this;
  }

  public on(event: string, listener: Listener) {
    return this.addListener(event, listener);
  }

  public once(event: string, listener: Listener) {
    const fn = () => {
      this.removeListener(event, fn);
      return listener(...arguments);
    };
    this.on(event, fn);
    return this;
  }

  public removeListener(event: string, listener: Listener) {
    if (!this.listeners[event]) { return this; }
    this.listeners[event] = this.listeners[event].filter((l) => l !== listener);
    return this;
  }

  public removeAllListeners(event: string) {
    delete this.listeners[event];
    return this;
  }

  public off(event: string, listener: Listener) {
    return this.removeListener(event, listener);
  }

  // ordered set of hooks for mutating
  // NOTE: a little weird for eventEmitter to be in charge of this

  public addHook(event: string, transform: Hook) {
    if (!this.hooks[event]) {
      this.hooks[event] = [];
    }
    this.hooks[event].push(transform);
    return this;
  }

  public removeHook(event: string, transform: Hook) {
    if (!this.hooks[event]) { return this; }
    this.hooks[event] = this.hooks[event].filter((t) => t !== transform);
    return this;
  }

  public applyHook(event: string, obj: any, info: any) {
    (this.hooks[event] || []).forEach((transform) => {
      obj = transform(obj, info);
    });
    return obj;
  }

  public async applyHookAsync(event: string, obj: any, info: any) {
    const hooks = (this.hooks[event] || []);
    for (let i = 0; i < hooks.length; i++) {
      const transform = hooks[i];
      obj = await transform(obj, info);
    }
    return obj;
  }
}
