// based on https://gist.github.com/contra/2759355

export default class EventEmitter {
  constructor() {
    // mapping from event to list of listeners
    this.listeners = {};
    this.hooks = {};
  }

  // emit an event and return all responses from the listeners
  emit(event, ...args) {
    return (this.listeners['all'] || []).map((listener) => {
      return listener.apply(listener, arguments);
    }).concat(
      (this.listeners[event] || []).map((listener) => {
        return listener.apply(listener, args);
      })
    );
  }

  addListener(event, listener) {
    this.emit('newListener', event, listener);
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(listener);
    return this;
  }

  on() {
    return this.addListener.apply(this, arguments);
  }

  once(event, listener) {
    const fn = function() {
      this.removeListener(event, fn);
      return listener(...arguments);
    };
    this.on(event, fn);
    return this;
  }

  removeListener(event, listener) {
    if (!this.listeners[event]) { return this; }
    this.listeners[event] = this.listeners[event].filter((l) => l !== listener);
    return this;
  }

  removeAllListeners(event) {
    delete this.listeners[event];
    return this;
  }

  off() {
    return this.removeListener.apply(this, arguments);
  }

  // ordered set of hooks for mutating
  // NOTE: a little weird for eventEmitter to be in charge of this

  addHook(event, transform) {
    if (!this.hooks[event]) {
      this.hooks[event] = [];
    }
    this.hooks[event].push(transform);
    return this;
  }

  removeHook(event, transform) {
    if (!this.hooks[event]) { return this; }
    this.hooks[event] = this.hooks[event].filter((t) => t !== transform);
    return this;
  }

  applyHook(event, obj, info) {
    (this.hooks[event] || []).forEach((transform) => {
      obj = transform(obj, info);
    });
    return obj;
  }
}
