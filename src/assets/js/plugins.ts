import * as _ from 'lodash';

import * as Modes from './modes';
import logger, { Logger } from './logger';
import * as errors from './errors';
import EventEmitter from './eventEmitter';
import Document from './document';
import Cursor from './cursor';
import Session from './session';
import defaultKeyMappings, { HotkeyMapping } from './keyMappings';
import { KeyBindings } from './keyBindings';
import { KeyDefinitions, Action, Motion } from './keyDefinitions';

type PluginMetadata = {
  name: string;
  version?: number;
  author?: string;
  description?: string;
};

// global set of registered plugins
const PLUGINS = {};

export enum STATUSES {
  UNREGISTERED = 0,
  DISABLING = 1,
  DISABLED = 2,
  ENABLING = 3,
  ENABLED = 4,
};

// class for exposing plugin API
export class PluginApi {
  public session: Session;
  private metadata: PluginMetadata;
  private pluginManager: PluginsManager;
  private name: string;
  private document: Document;
  public cursor: Cursor;
  public logger: Logger;
  private bindings: KeyBindings;
  private definitions: KeyDefinitions;

  private registrations: Array<() => void>;

  constructor(session, metadata, pluginManager) {
    this.session = session;
    this.metadata = metadata;
    this.pluginManager = pluginManager;
    this.name = this.metadata.name;
    this.document = this.session.document;
    this.cursor = this.session.cursor;
    // TODO: Add subloggers and prefix all log messages with the plugin name
    this.logger = logger;

    this.bindings = this.session.bindings;
    this.definitions = this.bindings.definitions;

    this.registrations = [];
  }

  public async setData(key: string, value: any) {
    return await this.document.store.setPluginData(this.name, key, value);
  }

  public async getData(key: string, default_value: any = null) {
    return await this.document.store.getPluginData(this.name, key, default_value);
  }

  // marks row for re-rendering
  public async updatedDataForRender(row) {
    // this is sort of a weird implementation,
    // but it causes the cachedRowInfo to get updated
    // and also updates pluginData, which is the typical use case
    await this.document.updateCachedPluginData(row);
  }

  public registerMode(metadata) {
    const mode = Modes.registerMode(metadata);
    this.registrations.push(() => {
      this.deregisterMode(mode);
    });
    return mode;
  }

  public deregisterMode(mode) {
    Modes.deregisterMode(mode);
  }

  public registerDefaultMappings(mode: string, mappings: HotkeyMapping) {
    defaultKeyMappings.registerModeMappings(mode, mappings);
    this.registrations.push(() => {
      this.deregisterDefaultMappings(mode, mappings);
    });
  }

  public deregisterDefaultMappings(mode: string, mappings: HotkeyMapping) {
    defaultKeyMappings.deregisterModeMappings(mode, mappings);
  }

  public registerMotion(name, desc, def) {
    const motion = new Motion(name, desc, def);
    this.definitions.registerMotion(motion);
    this.registrations.push(() => {
      this.deregisterMotion(motion.name);
    });
    return motion;
  }

  public deregisterMotion(name) {
    this.definitions.deregisterMotion(name);
  }

  public registerAction(name, desc, def) {
    const action = new Action(name, desc, def);
    this.definitions.registerAction(action);
    this.registrations.push(() => {
      this.deregisterAction(action.name);
    });
    return action;
  }

  public deregisterAction(name) {
    this.definitions.deregisterAction(name);
  }

  private _getEmitter(who): Document | Session {
    if (who === 'document') {
      return this.document;
    } else if (who === 'session') {
      return this.session;
    } else {
      throw new errors.GenericError `Unknown hook listener ${who}`;
    }
  }

  public registerListener(who, event, listener) {
    const emitter = this._getEmitter(who);
    emitter.on(event, listener);
    this.registrations.push(() => {
      this.deregisterListener(who, event, listener);
    });
  }

  public deregisterListener(who, event, listener) {
    const emitter = this._getEmitter(who);
    emitter.off(event, listener);
  }

  public registerHook(who, event, transform) {
    const emitter = this._getEmitter(who);
    emitter.addHook(event, transform);
    this.registrations.push(() => {
      this.deregisterHook(who, event, transform);
    });
    this.document.refreshRender();
  }

  public deregisterHook(who, event, transform) {
    const emitter = this._getEmitter(who);
    emitter.removeHook(event, transform);
    this.document.refreshRender();
  }

  public deregisterAll() {
    this.registrations.reverse().forEach((deregisterFn) => {
      deregisterFn();
    });
    this.registrations = [];
  }

  public async panic() {
    // await this.pluginManager.disable(this.name);
    throw new Error(
      `Plugin '${this.name}' has encountered a major problem.
      Please report this problem to the plugin author.`
    );
  }
}

export class PluginsManager extends EventEmitter {
  private session: Session;
  private plugin_infos: {
    [key: string]: {
      api?: PluginApi,
      value?: any,
      status?: STATUSES,
    }
  };

  constructor(session) {
    super();
    this.session = session;
    this.plugin_infos = {};
  }

  public getInfo(name) {
    return this.plugin_infos[name];
  }

  public getStatus(name) {
    if (!PLUGINS[name]) {
      return STATUSES.UNREGISTERED;
    }
    return (this.plugin_infos[name] && this.plugin_infos[name].status) || STATUSES.DISABLED;
  }

  public setStatus(name, status) {
    logger.debug(`Plugin ${name} status: ${status}`);
    if (!PLUGINS[name]) {
      throw new Error(`Plugin ${name} was not registered`);
    }
    const plugin_info = this.plugin_infos[name] || {};
    plugin_info.status = status;
    this.plugin_infos[name] = plugin_info;
    this.emit('status');
  }

  public updateEnabledPlugins() {
    const enabled: Array<string> = [];
    for (const name in this.plugin_infos) {
      if ((this.getStatus(name)) === STATUSES.ENABLED) {
        enabled.push(name);
      }
    }
    this.emit('enabledPluginsChange', enabled);
  }

  public async enable(name) {
    const status = this.getStatus(name);
    if (status === STATUSES.UNREGISTERED) {
      logger.error(`No plugin registered as ${name}`);
      PLUGINS[name] = null;
      return;
    }
    if (status === STATUSES.ENABLING) {
      throw new errors.GenericError(`Already enabling plugin ${name}`);
    }
    if (status === STATUSES.DISABLING) {
      throw new errors.GenericError(`Still disabling plugin ${name}`);
    }
    if (status === STATUSES.ENABLED) {
      throw new errors.GenericError(`Plugin ${name} is already enabled`);
    }

    errors.assert(status === STATUSES.DISABLED);
    this.setStatus(name, STATUSES.ENABLING);

    const plugin = PLUGINS[name];
    const api = new PluginApi(this.session, plugin, this);
    const value = await plugin.enable(api);

    this.plugin_infos[name] = { api, value };
    this.setStatus(name, STATUSES.ENABLED);
    this.updateEnabledPlugins();
  }

  public async disable(name) {
    const status = this.getStatus(name);
    if (status === STATUSES.UNREGISTERED) {
      throw new errors.GenericError(`No plugin registered as ${name}`);
    }
    if (status === STATUSES.ENABLING) {
      throw new errors.GenericError(`Still enabling plugin ${name}`);
    }
    if (status === STATUSES.DISABLING) {
      throw new errors.GenericError(`Already disabling plugin ${name}`);
    }
    if (status === STATUSES.DISABLED) {
      throw new errors.GenericError(`Plugin ${name} already disabled`);
    }

    // TODO: require that no other plugin has this as a dependency, notify user otherwise
    errors.assert(status === STATUSES.ENABLED);
    this.setStatus(name, STATUSES.DISABLING);

    const plugin_info = this.plugin_infos[name];
    const plugin = PLUGINS[name];
    await plugin.disable(plugin_info.api, plugin_info.value);
    delete this.plugin_infos[name];
    this.updateEnabledPlugins();
  }
}

const registerPlugin = function(
  plugin_metadata: PluginMetadata, enable, disable
) {
  plugin_metadata.version = plugin_metadata.version || 1;
  plugin_metadata.author = plugin_metadata.author || 'anonymous';

  errors.assert(enable, `Plugin ${plugin_metadata.name} needs to register with a callback`);

  // Create the plugin object
  // Plugin stores all data about a plugin, including metadata
  // plugin.value contains the actual resolved value
  const plugin: any = _.cloneDeep(plugin_metadata);
  PLUGINS[plugin.name] = plugin;
  plugin.enable = enable;
  plugin.disable = disable || _.once(function(api) {
    api.deregisterAll();
    throw new Error(
      `The plugin '${plugin.name}' was disabled but doesn't support online disable functionality. Refresh to disable.`
    );
  });
};

// exports
export { registerPlugin as register };
export function all() { return PLUGINS; }
export function getPlugin(name) { return PLUGINS[name]; }
export function names() { return (_.keys(PLUGINS)).sort(); }
