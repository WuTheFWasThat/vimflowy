// based on https://gist.github.com/contra/2759355

export default class EventEmitter {
  private listeners: {[key: string]: Array<(...args: any[]) => any>};
  private hooks: {[key: string]: Array<(obj: any, info: any) => any>};

  constructor() {
    // mapping from event to list of listeners
    this.listeners = {};
    this.hooks = {};
  }

  // emit an event and return all responses from the listeners
  public emit(event, ...args) {
    return (this.listeners[event] || []).map((listener) => {
      return listener.apply(listener, args);
    });
  }

  public emitAsync(event, ...args) {
    return Promise.all((this.listeners[event] || []).map(async (listener) => {
      return await listener.apply(listener, args);
    }));
  }

  public addListener(event, listener) {
    this.emit('newListener', event, listener);
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(listener);
    return this;
  }

  public on(event, listener) {
    return this.addListener(event, listener);
  }

  public once(event, listener) {
    const fn = function() {
      this.removeListener(event, fn);
      return listener(...arguments);
    };
    this.on(event, fn);
    return this;
  }

  public removeListener(event, listener) {
    if (!this.listeners[event]) { return this; }
    this.listeners[event] = this.listeners[event].filter((l) => l !== listener);
    return this;
  }

  public removeAllListeners(event) {
    delete this.listeners[event];
    return this;
  }

  public off(event, listener) {
    return this.removeListener(event, listener);
  }

  // ordered set of hooks for mutating
  // NOTE: a little weird for eventEmitter to be in charge of this

  public addHook(event, transform) {
    if (!this.hooks[event]) {
      this.hooks[event] = [];
    }
    this.hooks[event].push(transform);
    return this;
  }

  public removeHook(event, transform) {
    if (!this.hooks[event]) { return this; }
    this.hooks[event] = this.hooks[event].filter((t) => t !== transform);
    return this;
  }

  public applyHook(event, obj, info) {
    (this.hooks[event] || []).forEach((transform) => {
      obj = transform(obj, info);
    });
    return obj;
  }

  public async applyHookAsync(event, obj, info) {
    const hooks = (this.hooks[event] || []);
    for (let i = 0; i < hooks.length; i++) {
      const transform = hooks[i];
      obj = await transform(obj, info);
    }
    return obj;
  }
}
