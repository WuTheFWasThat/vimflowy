// based on https://gist.github.com/contra/2759355

// TODO: get rid of all the anys in this file.  use new typescript feature, like
// export default class EventEmitter<LTypes> {
//   private listeners: {[K in keyof LTypes]: Array<(...args: LTypes[K]) => any>};
//

export type Listener = (...args: any[]) => any;

export default class EventEmitter {
  private listeners: {[key: string]: Array<Listener>};

  constructor() {
    // mapping from event to list of listeners
    this.listeners = {};
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
    const fn = (...args: Array<any>) => {
      this.removeListener(event, fn);
      return listener(args);
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
}
