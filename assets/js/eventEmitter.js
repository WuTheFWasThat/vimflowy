// based on https://gist.github.com/contra/2759355

class EventEmitter {
  constructor() {
    // mapping from event to list of listeners
    this.listeners = {};
    this.hooks = {};
  }

  // emit an event and return all responses from the listeners
  // TODO
  // emit: (event, args...) ->
  //   ((listener event, args...) for listener in (@listeners['all'] or []))
  //   return ((listener args...) for listener in (@listeners[event] or []))

  addListener(event, listener) {
    this.emit('newListener', event, listener);
    (this.listeners[event] != null ? this.listeners[event]: (this.listeners[event] =[])).push(listener);
    return this;
  }

  on = this.prototype.addListener;

  once(event, listener) {
    let fn = function() {
      this.removeListener(event, fn);
      return listener(...arguments);
    };
    this.on(event, fn);
    return this;
  }

  removeListener(event, listener) {
    if (!this.listeners[event]) { return this; }
    // TODO
    //   @listeners[event] = (l for l in @listeners[event] when l isnt listener)
    return this;
  }

  removeAllListeners(event) {
    delete this.listeners[event];
    return this;
  }

  off = this.prototype.removeListener;

  // ordered set of hooks for mutating
  // NOTE: a little weird for eventEmitter to be in charge of this

  addHook(event, transform) {
    return (this.hooks[event] != null ? this.hooks[event]: (this.hooks[event] =[])).push(transform);
  }

  removeHook(event, transform) {
    if (!this.hooks[event]) { return this; }
    // TODO
    // @hooks[event] = (t for t in @hooks[event] when t isnt transform)
    return this;
  }

  applyHook(event, obj, info) {
    let iterable = this.hooks[event] || [];
    for (let i = 0; i < iterable.length; i++) {
      let transform = iterable[i];
      obj = transform(obj, info);
    }
    return obj;
  }
}

// exports
export default EventEmitter;
