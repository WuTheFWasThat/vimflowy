/* globals alert */

import _ from 'lodash';

import * as utils from './utils';
import * as Modes from './modes';
import * as Logger from './logger';
import * as errors from './errors';
import EventEmitter from './eventEmitter';

let PLUGIN_SCHEMA = {
  title: 'Plugin metadata schema',
  type: 'object',
  required: [ 'name' ],
  properties: {
    name: {
      description: 'Name of the plugin',
      pattern: '^[A-Za-z0-9_ ]{2,64}$',
      type: 'string'
    },
    version: {
      description: 'Version of the plugin',
      type: 'number',
      default: 1,
      minimum: 1
    },
    author: {
      description: 'Author of the plugin',
      type: 'string',
      default: 'Unknown'
    },
    description: {
      description: 'Description of the plugin',
      type: 'string'
    }
  }
};

// global set of registered plugins
const PLUGINS = {};

const STATUSES = {
  UNREGISTERED: 'Unregistered',
  DISABLING: 'Disabling',
  ENABLING: 'Enabling',
  DISABLED: 'Disabled',
  ENABLED: 'Enabled',
};


// class for exposing plugin API
class PluginApi {
  constructor(session, metadata, pluginManager) {
    this.session = session;
    this.metadata = metadata;
    this.pluginManager = pluginManager;
    this.name = this.metadata.name;
    this.document = this.session.document;
    this.cursor = this.session.cursor;
    // TODO: Add subloggers and prefix all log messages with the plugin name
    this.logger = Logger.logger;

    this.bindings = this.session.bindings;
    this.definitions = this.bindings.definitions;
    this.commands = this.definitions.commands;

    this.registrations = [];
  }

  setData(key, value) {
    return this.document.store.setPluginData(this.name, key, value);
  }

  getData(key, default_value=null) {
    return this.document.store.getPluginData(this.name, key, default_value);
  }

  // TODO: have definitions be event emitter? have this be automatic somehow
  //       (first try combining bindings into definitions)
  //       should also re-render mode table
  _reapply_hotkeys() {
    let err = this.session.bindings.reapply_hotkey_settings();
    if (err) {
      throw new errors.GenericError(`Error applying hotkeys: ${err}`);
    }
  }

  registerMode(metadata) {
    let mode = Modes.registerMode(metadata);
    this.registrations.push({type: 'mode', args: [mode]});
    return this._reapply_hotkeys();
  }

  deregisterMode(mode) {
    Modes.deregisterMode(mode);
    return this._reapply_hotkeys();
  }

  registerCommand(metadata) {
    let cmd = this.definitions.registerCommand(metadata);
    this.registrations.push({type: 'command', args: [cmd]});
    this._reapply_hotkeys();
    return cmd;
  }

  deregisterCommand(command) {
    this.definitions.deregisterCommand(command);
    return this._reapply_hotkeys();
  }

  registerMotion(commands, motion, definition) {
    this.definitions.registerMotion(commands, motion, definition);
    this.registrations.push({type: 'motion', args: [commands]});
    return this._reapply_hotkeys();
  }

  deregisterMotion(commands) {
    this.definitions.deregisterMotion(commands);
    return this._reapply_hotkeys();
  }

  registerAction(modes, commands, action, definition) {
    this.definitions.registerAction(modes, commands, action, definition);
    this.registrations.push({type: 'action', args: [modes, commands]});
    return this._reapply_hotkeys();
  }

  deregisterAction(modes, commands) {
    this.definitions.deregisterAction(modes, commands);
    return this._reapply_hotkeys();
  }

  _getEmitter(who) {
    if (who === 'document') {
      return this.document;
    } else if (who === 'session') {
      return this.session;
    } else {
      throw new errors.GenericError `Unknown hook listener ${who}`;
    }
  }

  registerListener(who, event, listener) {
    let emitter = this._getEmitter(who);
    emitter.on(event, listener);
    return this.registrations.push({type: 'listener', args: [who, event, listener]});
  }

  deregisterListener(who, event, listener) {
    let emitter = this._getEmitter(who);
    return emitter.off(event, listener);
  }

  registerHook(who, event, transform) {
    let emitter = this._getEmitter(who);
    emitter.addHook(event, transform);
    return this.registrations.push({type: 'hook', args: [who, event, transform]});
  }

  deregisterHook(who, event, transform) {
    let emitter = this._getEmitter(who);
    return emitter.removeHook(event, transform);
  }

  deregisterAll() {
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
    return this.registrations = [];
  }

  panic() {
    alert(`Plugin '${this.name}' has encountered a major problem. Please report this problem to the plugin author.`);
    return this.pluginManager.disable(this.name);
  }
}

class PluginsManager extends EventEmitter {

  constructor(session, div) {
    super();
    this.session = session;
    this.div = div;
    this.plugin_infos = {};
  }

  get(name) {
    return this.plugin_infos[name];
  }

  getStatus(name) {
    if (!PLUGINS[name]) {
      return STATUSES.UNREGISTERED;
    }
    return (this.plugin_infos[name] && this.plugin_infos[name].status) || STATUSES.DISABLED;
  }

  setStatus(name, status) {
    Logger.logger.info(`Plugin ${name} status: ${status}`);
    if (!PLUGINS[name]) {
      throw new Error(`Plugin ${name} was not registered`);
    }
    let plugin_info = this.plugin_infos[name] || {};
    plugin_info.status = status;
    this.plugin_infos[name] = plugin_info;
    return this.emit('status');
  }

  updateEnabledPlugins() {
    let enabled = [];
    for (let name in this.plugin_infos) {
      if ((this.getStatus(name)) === STATUSES.ENABLED) {
        enabled.push(name);
      }
    }
    return this.emit('enabledPluginsChange', enabled);
  }

  enable(name) {
    let status = this.getStatus(name);
    if (status === STATUSES.UNREGISTERED) {
      Logger.logger.error(`No plugin registered as ${name}`);
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

    errors.assert((status === STATUSES.DISABLED));
    this.setStatus(name, STATUSES.ENABLING);

    let plugin = PLUGINS[name];
    let api = new PluginApi(this.session, plugin, this);
    let value = plugin.enable(api);

    this.plugin_infos[name] = {
      api,
      value
    };
    this.setStatus(name, STATUSES.ENABLED);
    return this.updateEnabledPlugins();
  }

  disable(name) {
    let status = this.getStatus(name);
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
    errors.assert((status === STATUSES.ENABLED));
    this.setStatus(name, STATUSES.DISABLING);

    let plugin_info = this.plugin_infos[name];
    let plugin = PLUGINS[name];
    plugin.disable(plugin_info.api, plugin_info.value);
    delete this.plugin_infos[name];
    return this.updateEnabledPlugins();
  }
}

let registerPlugin = function(plugin_metadata, enable, disable) {
  utils.tv4_validate(plugin_metadata, PLUGIN_SCHEMA, 'plugin');
  utils.fill_tv4_defaults(plugin_metadata, PLUGIN_SCHEMA);

  errors.assert(enable, `Plugin ${plugin_metadata.name} needs to register with a callback`);

  // Create the plugin object
  // Plugin stores all data about a plugin, including metadata
  // plugin.value contains the actual resolved value
  let plugin = _.cloneDeep(plugin_metadata);
  PLUGINS[plugin.name] = plugin;
  plugin.enable = enable;
  return plugin.disable = disable || _.once(function(api) {
    api.deregisterAll();
    return alert(
      `The plugin '${plugin.name}' was disabled but doesn't support online disable functionality. Refresh to disable.`
    );
  });
};

// exports
export { PluginsManager };
export { registerPlugin as register };
export function all() { return PLUGINS; }
export function get(name) { return PLUGINS[name]; }
export function names() { return (_.keys(PLUGINS)).sort(); }
export { STATUSES };
