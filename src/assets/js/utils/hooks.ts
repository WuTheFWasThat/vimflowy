// NOTE: ideally would be like
//   export type Hook<T, A extends Array<any>> = (obj: T, ...info: A) => T;
// but typescript doesn't support this.
// SEE: https://github.com/Microsoft/TypeScript/issues/1024
export type Hook<T, I> = (obj: T, info: I) => T;

// TODO: add way to insert hooks at other indices, reorder hooks?
export class HookManager<T, I> {
  // ordered set of hooks for mutating
  private hooks: Array<Hook<T, I>>;

  constructor() {
    this.hooks = [];
  }

  public add(hook: Hook<T, I>) {
    this.hooks.push(hook);
    return this;
  }

  public remove(hook: Hook<T, I>) {
    this.hooks = this.hooks.filter((h) => h !== hook);
    return this;
  }

  public apply(obj: T, info: I) {
    this.hooks.forEach((hook) => {
      obj = hook(obj, info);
    });
    return obj;
  }

  public async applyAsync(obj: T, info: I): Promise<T> {
    for (let i = 0; i < this.hooks.length; i++) {
      const hook = this.hooks[i];
      obj = await hook(obj, info);
    }
    return obj;
  }
}

// One hook manager for each string key
export default class HooksManager<HookTypes> {
  // TODO: have way to have the info type?
  private hookManagers: {[K in keyof HookTypes]?: HookManager<HookTypes[K], any>};

  constructor() {
    this.hookManagers = {};
  }

  public add<K extends keyof HookTypes>(event: K, hook: Hook<HookTypes[K], any>) {
    if (!this.hookManagers[event]) {
      this.hookManagers[event] = new HookManager<HookTypes[K], any>();
    }
    this.hookManagers[event].add(hook);
    return this;
  }

  public remove<K extends keyof HookTypes>(event: K, hook: Hook<HookTypes[K], any>) {
    if (!this.hookManagers[event]) { return this; }
    this.hookManagers[event].remove(hook);
    return this;
  }

  public apply<K extends keyof HookTypes>(event: K, obj: HookTypes[K], info: any) {
    if (this.hookManagers[event]) {
      return this.hookManagers[event].apply(obj, info);
    }
    return obj;
  }

  public async applyAsync<K extends keyof HookTypes>(event: K, obj: HookTypes[K], info: any): Promise<HookTypes[K]> {
    if (this.hookManagers[event]) {
      return await this.hookManagers[event].applyAsync(obj, info);
    }
    return obj;
  }
}
