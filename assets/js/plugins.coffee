_ = require 'lodash'

utils = require './utils.coffee'
Modes = require './modes.coffee'
Logger = require './logger.coffee'
errors = require './errors.coffee'

PLUGIN_SCHEMA = {
  title: "Plugin metadata schema"
  type: "object"
  required: [ 'name' ]
  properties: {
    name: {
      description: "Name of the plugin"
      pattern: "^[A-Za-z0-9_ ]{2,64}$"
      type: "string"
    }
    version: {
      description: "Version of the plugin"
      type: "number"
      default: 1
      minimum: 1
    }
    author: {
      description: "Author of the plugin"
      type: "string"
      default: "Unknown"
    }
    description: {
      description: "Description of the plugin"
      type: "string"
    }
  }
}

# global set of registered plugins
PLUGINS = {}

getPluginNames = () ->
  do (_.keys PLUGINS).sort

# class for exposing plugin API
class PluginApi
  constructor: (@session, @metadata, @pluginManager) ->
    @name = @metadata.name
    @document = @session.document
    @cursor = @session.cursor
    # TODO: Add subloggers and prefix all log messages with the plugin name
    @logger = Logger.logger

    @bindings = @session.bindings
    @definitions = @bindings.definitions
    @commands = @definitions.commands

  setData: (key, value) ->
    @document.store.setPluginData @name, key, value

  getData: (key, default_value=null) ->
    @document.store.getPluginData @name, key, default_value

  registerMode: (metadata) ->
    Modes.registerMode metadata
    do @session.bindings.init

  registerCommand: (metadata) ->
    cmd = @definitions.registerCommand metadata
    do @session.bindings.init
    return cmd

  registerMotion: (commands, motion, definition) ->
    @definitions.registerMotion commands, motion, definition
    do @session.bindings.init

  registerAction: (modes, commands, action, definition) ->
    @definitions.registerAction modes, commands, action, definition
    do @session.bindings.init

  panic: _.once () =>
    alert "Plugin '#{@name}' has encountered a major problem. Please report this problem to the plugin author."
    @pluginManager.disable @name

class PluginsManager

  STATUS = {
    UNREGISTERED: "Unregistered",
    DISABLING: "Disabling",
    ENABLING: "Enabling",
    DISABLED: "Disabled",
    ENABLED: "Enabled",
  }

  constructor: (session, div) ->
    @session = session
    @div = div
    @plugin_infos = {}
    do @render

  render: () ->
    unless @div?
      return
    vtree = do @virtualRender
    if @vtree?
      patches = virtualDom.diff @vtree, vtree
      @vnode = virtualDom.patch @vnode, patches
      @vtree = vtree
    else
      $(@div).find(".before-load").remove()
      @vtree = do @virtualRender
      @vnode = virtualDom.create @vtree
      @div.append @vnode

  virtualRender: () ->
    header = virtualDom.h 'tr', {}, [
      virtualDom.h 'th', { className: 'plugin-name' }, "Plugin"
      virtualDom.h 'th', { className: 'plugin-description' }, "Description"
      virtualDom.h 'th', { className: 'plugin-version' }, "Version"
      virtualDom.h 'th', { className: 'plugin-author' }, "Author"
      virtualDom.h 'th', { className: 'plugin-status' }, "Status"
      virtualDom.h 'th', { className: 'plugin-actions' }, "Actions"
    ]
    pluginElements = (@virtualRenderPlugin name for name in do getPluginNames)
    virtualDom.h 'table', {}, ([header].concat pluginElements)

  virtualRenderPlugin: (name) ->
    status = @getStatus name
    actions = []
    if status == STATUS.ENABLED
      # "Disable" action
      button = virtualDom.h 'div', {
          className: 'btn theme-trim'
          onclick: () => @disable name
      }, "Disable"
      actions.push button
    else if status == STATUS.DISABLED
      # "Enable" action
      button = virtualDom.h 'div', {
          className: 'btn theme-trim'
          onclick: () => @enable name
      }, "Enable"
      actions.push button

    color = "inherit"
    if status == STATUS.ENABLING or status == STATUS.DISABLING
      color = "yellow"
    if status == STATUS.UNREGISTERED or status == STATUS.DISABLED
      color = "red"
    else if status == STATUS.ENABLED
      color = "green"

    plugin = PLUGINS[name] || {}
    virtualDom.h 'tr', {
      className: "plugin theme-bg-secondary"
    }, [
      virtualDom.h 'td', { className: 'center theme-trim plugin-name' }, name
      virtualDom.h 'td', { className: 'theme-trim plugin-description', style: {'font-size': '12px'} }, (plugin.description || '')
      virtualDom.h 'td', { className: 'center theme-trim plugin-version' }, ((plugin.version || '') + '')
      virtualDom.h 'td', { className: 'center theme-trim plugin-author', style: {'font-size': '12px'} }, (plugin.author || '')
      virtualDom.h 'td', { className: 'center theme-trim plugin-status', style: {'box-shadow': 'inset 0px 0px 0px 2px ' + color } }, status
      virtualDom.h 'td', { className: 'center theme-trim plugin-actions' }, actions
    ]

  get: (name) ->
    return @plugin_infos[name]

  getStatus: (name) ->
    if not (name of PLUGINS)
      return STATUS.UNREGISTERED
    @plugin_infos[name]?.status || STATUS.DISABLED

  setStatus: (name, status) ->
    Logger.logger.info "Plugin #{name} status: #{status}"
    if not PLUGINS[name]?
      throw new Error "Plugin #{name} was not registered"
    plugin_info = @plugin_infos[name] || {}
    plugin_info.status = status
    @plugin_infos[name] = plugin_info
    do @render

  updateEnabledPlugins: () ->
    enabled = []
    for name of @plugin_infos
      if (@getStatus name) == STATUS.ENABLED
        enabled.push name
    if @session.settings
      console.log 'updating settings'
      @session.settings.setSetting "enabledPlugins", enabled

    # refresh hotkeys, if any new ones were added/removed
    do @session.bindings.init
    @session.bindings.renderModeTable @session.mode
    # TODO: also re-render main session
    # TODO: move all this logic out of the manager, anyways

  enable: (name) ->
    status = @getStatus name
    if status == STATUS.UNREGISTERED
      Logger.logger.error "No plugin registered as #{name}"
      return
    if status == STATUS.ENABLING
      throw new errors.GenericError("Already enabling plugin #{name}")
    if status == STATUS.DISABLING
      throw new errors.GenericError("Still disabling plugin #{name}")
    if status == STATUS.ENABLED
      throw new errors.GenericError("Plugin #{name} is already enabled")

    errors.assert (status == STATUS.DISABLED)
    @setStatus name, STATUS.ENABLING

    plugin = PLUGINS[name]
    api = new PluginApi @session, plugin, @
    value = plugin.enable api

    @plugin_infos[name] = {
      api: api,
      value: value
    }
    @setStatus name, STATUS.ENABLED
    do @updateEnabledPlugins

  disable: (name) ->
    status = @getStatus name
    if status == STATUS.UNREGISTERED
      throw new errors.GenericError("No plugin registered as #{name}")
    if status == STATUS.ENABLING
      throw new errors.GenericError("Still enabling plugin #{name}")
    if status == STATUS.DISABLING
      throw new errors.GenericError("Already disabling plugin #{name}")
    if status == STATUS.DISABLED
      throw new errors.GenericError("Plugin #{name} already disabled")

    # TODO: require that no other plugin has this as a dependency, notify user otherwise
    errors.assert (status == STATUS.ENABLED)
    @setStatus name, STATUS.DISABLING

    plugin_info = @plugin_infos[name]
    plugin = PLUGINS[name]
    plugin.disable plugin_info.api
    delete @plugin_infos[name]
    do @updateEnabledPlugins

registerPlugin = (plugin_metadata, enable, disable) ->
  utils.tv4_validate(plugin_metadata, PLUGIN_SCHEMA, "plugin")
  utils.fill_tv4_defaults plugin_metadata, PLUGIN_SCHEMA

  errors.assert enable?, "Plugin #{plugin_metadata.name} needs to register with a callback"

  # Create the plugin object
  # Plugin stores all data about a plugin, including metadata
  # plugin.value contains the actual resolved value
  plugin = _.cloneDeep plugin_metadata
  PLUGINS[plugin.name] = plugin
  plugin.enable = enable
  plugin.disable = disable || _.once () =>
    alert "The plugin '#{plugin.name}' was disabled but doesn't support online disable functionality. Refresh to disable."

# exports
exports.PluginsManager = PluginsManager
exports.register = registerPlugin
exports.all = () ->
  return PLUGINS
