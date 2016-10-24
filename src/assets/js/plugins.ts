/* globals alert */

import * as _ from 'lodash';

import * as Modes from './modes';
import logger, { Logger } from './logger';
import * as errors from './errors';
import EventEmitter from './eventEmitter';
import Document from './document';
import Cursor from './cursor';
import Session from './session';
import KeyBindings from './keyBindings';
import { KeyDefinitions, Command } from './keyDefinitions';

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
  private cursor: Cursor;
  public logger: Logger;
  private bindings: KeyBindings;
  private definitions: KeyDefinitions;
  public commands: { [key: string]: Command };

  private registrations: Array<any>; // TODO

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
    this.commands = this.definitions.commands;

    this.registrations = [];
  }

  public async setData(key, value) {
    return await this.document.store.setPluginData(this.name, key, value);
  }

  public async getData(key, default_value = null) {
    return await this.document.store.getPluginData(this.name, key, default_value);
  }

  public getDataSync(key) {
    return this.document.store.getPluginDataSync(this.name, key);
  }

  // TODO: have definitions be event emitter? have this be automatic somehow
  //       (first try combining bindings into definitions)
  //       should also re-render mode table
  private _reapply_hotkeys() {
    const err = this.session.bindings.reapply_hotkey_settings();
    if (err) {
      throw new errors.GenericError(`Error applying hotkeys: ${err}`);
    }
  }

  public registerMode(metadata) {
    const mode = Modes.registerMode(metadata);
    this.registrations.push({type: 'mode', args: [mode]});
    this._reapply_hotkeys();
    return mode;
  }

  public deregisterMode(mode) {
    Modes.deregisterMode(mode);
    this._reapply_hotkeys();
  }

  public registerCommand(metadata) {
    const cmd = this.definitions.registerCommand(metadata);
    this.registrations.push({type: 'command', args: [cmd]});
    this._reapply_hotkeys();
    return cmd;
  }

  public deregisterCommand(command) {
    this.definitions.deregisterCommand(command);
    this._reapply_hotkeys();
  }

  public registerMotion(commands, motion, definition) {
    this.definitions.registerMotion(commands, motion, definition);
    this.registrations.push({type: 'motion', args: [commands]});
    this._reapply_hotkeys();
  }

  public deregisterMotion(commands) {
    this.definitions.deregisterMotion(commands);
    this._reapply_hotkeys();
  }

  public registerAction(modes, commands, action, definition) {
    this.definitions.registerAction(modes, commands, action, definition);
    this.registrations.push({type: 'action', args: [modes, commands]});
    this._reapply_hotkeys();
  }

  public deregisterAction(modes, commands) {
    this.definitions.deregisterAction(modes, commands);
    this._reapply_hotkeys();
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
    this.registrations.push({type: 'listener', args: [who, event, listener]});
  }

  public deregisterListener(who, event, listener) {
    const emitter = this._getEmitter(who);
    emitter.off(event, listener);
  }

  public registerHook(who, event, transform) {
    const emitter = this._getEmitter(who);
    emitter.addHook(event, transform);
    this.registrations.push({type: 'hook', args: [who, event, transform]});
  }

  public deregisterHook(who, event, transform) {
    const emitter = this._getEmitter(who);
    emitter.removeHook(event, transform);
  }

  public deregisterAll() {
    this.registrations.reverse().forEach((registration) => {
      if (registration.type === 'mode') {
        this.deregisterMode.apply(this, registration.args);
      } else if (registration.type === 'command') {
        this.deregisterCommand.apply(this, registration.args);
      } else if (registration.type === 'motion') {
        this.deregisterMotion.apply(this, registration.args);
      } else if (registration.type === 'action') {
        this.deregisterAction.apply(this, registration.args);
      } else if (registration.type === 'listener') {
        this.deregisterListener.apply(this, registration.args);
      } else if (registration.type === 'hook') {
        this.deregisterHook.apply(this, registration.args);
      } else {
        throw new errors.GenericError `Unknown registration type ${registration.type}`;
      }
    });
    this.registrations = [];
  }

  public async panic() {
    alert(`Plugin '${this.name}' has encountered a major problem. Please report this problem to the plugin author.`);
    await this.pluginManager.disable(this.name);
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
    const enabled = [];
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
    alert(
      `The plugin '${plugin.name}' was disabled but doesn't support online disable functionality. Refresh to disable.`
    );
  });
};

// exports
export { registerPlugin as register };
export function all() { return PLUGINS; }
export function getPlugin(name) { return PLUGINS[name]; }
export function names() { return (_.keys(PLUGINS)).sort(); }
