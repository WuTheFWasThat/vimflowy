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
    this.hookManagers = {} as any;
    // TODO wtf
    // this.hookManagers = {} as {[K in keyof HookTypes]?: HookManager<HookTypes[K], any>};
  }

  private getManager<K extends keyof HookTypes>(event: K): HookManager<HookTypes[K], any> {
    const maybeManager = this.hookManagers[event];
    if (maybeManager == null) {
      const manager = new HookManager<HookTypes[K], any>();
      this.hookManagers[event] = manager;
      return manager;
    } else {
      return maybeManager;
    }
  }

  public add<K extends keyof HookTypes>(event: K, hook: Hook<HookTypes[K], any>) {
    this.getManager(event).add(hook);
    return this;
  }

  public remove<K extends keyof HookTypes>(event: K, hook: Hook<HookTypes[K], any>) {
    this.getManager(event).remove(hook);
    return this;
  }

  public apply<K extends keyof HookTypes>(event: K, obj: HookTypes[K], info: any) {
    return this.getManager(event).apply(obj, info);
  }

  public async applyAsync<K extends keyof HookTypes>(event: K, obj: HookTypes[K], info: any): Promise<HookTypes[K]> {
    return await this.getManager(event).applyAsync(obj, info);
  }
}
