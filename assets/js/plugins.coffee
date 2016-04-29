_ = require 'lodash'

utils = require './utils.coffee'
Modes = require './modes.coffee'
Logger = require './logger.coffee'
errors = require './errors.coffee'
mutations = require './mutations.coffee'

# class for exposing plugin API
class PluginApi
  constructor: (@session, @metadata, @pluginManager) ->
    @name = @metadata.name
    @document = @session.document
    @cursor = @session.cursor
    # TODO: Add subloggers and prefix all log messages with the plugin name
    @logger = Logger.logger
    @Modes = Modes
    @modes = Modes.modes
    @Mutation = mutations.Mutation

    @bindings = @session.bindings
    @definitions = @bindings.definitions
    @commands = @definitions.commands

  setData: (key, value) ->
    @document.store.setPluginData @name, key, value

  getData: (key, default_value=null) ->
    @document.store.getPluginData @name, key, default_value

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

class PluginsManager

  STATUS = {
    UNREGISTERED: "Unregistered",
    DISABLING: "Disabling",
    ENABLING: "Enabling",
    DISABLED: "Disabled",
    ENABLED: "Enabled",
  }

  constructor: (options) ->
    # Default set of enabled plugins
    # Will be overridden before plugin loading, during 'resolveSession',
    # if any settings have been set
    @enabledPlugins = {
      "Marks": true
    }

    @plugins = {}

  validate: (plugin_metadata) ->
    utils.tv4_validate(plugin_metadata, PLUGIN_SCHEMA, "plugin")
    utils.fill_tv4_defaults plugin_metadata, PLUGIN_SCHEMA

  resolveSession: (session) ->
    @session = session
    if session.settings
      enabledPlugins = session.settings.getSetting "enabledPlugins"
    else
      # TODO: BAD HACK... to make unit tests work,
      # since each testcase uses the same pluginmanager but different session
      for name of @plugins
        @setStatus name, STATUS.DISABLED

    if enabledPlugins?
      @enabledPlugins = enabledPlugins
    @div = session.pluginsDiv
    do @render

    for plugin_name of @enabledPlugins
      @enable plugin_name

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
    pluginElements = (@virtualRenderPlugin name for name in do @getPluginNames)
    virtualDom.h 'table', {}, ([header].concat pluginElements)

  virtualRenderPlugin: (name) ->
    status = @getStatus name
    plugin = @plugins[name]
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

    virtualDom.h 'tr', {
      className: "plugin theme-bg-secondary"
    }, [
      virtualDom.h 'td', { className: 'center theme-trim plugin-name' }, name
      virtualDom.h 'td', { className: 'theme-trim plugin-description', style: {'font-size': '12px'} }, (plugin.description)
      virtualDom.h 'td', { className: 'center theme-trim plugin-version' }, (plugin.version + '')
      virtualDom.h 'td', { className: 'center theme-trim plugin-author', style: {'font-size': '12px'} }, plugin.author
      virtualDom.h 'td', { className: 'center theme-trim plugin-status', style: {'box-shadow': 'inset 0px 0px 0px 2px ' + color } }, status
      virtualDom.h 'td', { className: 'center theme-trim plugin-actions' }, actions
    ]

  getPluginNames: () ->
    do (_.keys @plugins).sort

  getStatus: (name) ->
    @plugins[name]?.status || STATUS.UNREGISTERED

  setStatus: (name, status) ->
    Logger.logger.info "Plugin #{name} status: #{status}"
    plugin = @plugins[name]
    if status != STATUS.UNREGISTERED and not plugin?
      throw new Error "Plugin status set but plugin was not registered"
    plugin.status = status
    do @render

  enable: (name) ->
    status = @getStatus name
    if status == STATUS.UNREGISTERED
      Logger.logger.error "No plugin registered as #{name}"
      return
    if status == STATUS.ENABLING
      throw new errors.GenericError("Already enabling plugin #{name}")
    if status == STATUS.DISABLING
      throw new errors.GenericError("Still disabling plugin #{name}")

    @enabledPlugins[name] = true
    if @session.settings
      @session.settings.setSetting "enabledPlugins", @enabledPlugins
    plugin = @plugins[name]
    if (status == STATUS.DISABLED) or (status == STATUS.UNREGISTERED)
      api = new PluginApi @session, plugin, @

      @setStatus plugin.name, STATUS.ENABLING
      plugin.api = api
      # TODO: allow enable to be async?
      plugin.value = plugin.enable api

      # refresh hotkeys, if any new ones were added
      do @session.bindings.init
      @session.bindings.renderModeTable @session.mode

    @setStatus plugin.name, STATUS.ENABLED

  disable: (name) ->
    status = @getStatus name
    if status == STATUS.UNREGISTERED
      throw new errors.GenericError("No plugin registered as #{name}")
    if status == STATUS.ENABLING
      throw new errors.GenericError("Still enabling plugin #{name}")
    if status == STATUS.DISABLING
      throw new errors.GenericError("Already disabling plugin #{name}")

    delete @enabledPlugins[name]
    if @session.settings
      @session.settings.setSetting "enabledPlugins", @enabledPlugins
    plugin = @plugins[name]

    # TODO: require that no other plugin has this as a dependency, notify user otherwise

    if status == STATUS.ENABLED
        @setStatus plugin.name, STATUS.DISABLING
        api = plugin.api
        # TODO: allow disable to be async?
        plugin.disable api
        delete plugin.api
        delete plugin.value
    @setStatus plugin.name, STATUS.DISABLED

  register: (plugin_metadata, enable, disable) ->
    @validate plugin_metadata
    errors.assert enable?, "Plugin #{plugin_metadata.name} needs to register with a callback"

    # Create the plugin object
    # Plugin stores all data about a plugin, including metadata
    # plugin.value contains the actual resolved value
    plugin = _.cloneDeep plugin_metadata
    @plugins[plugin.name] = plugin
    plugin.enable = enable
    plugin.disable = disable || _.once () =>
      alert "The plugin '#{plugin.name}' was disabled but doesn't support online disable functionality. Refresh to disable."
    @setStatus plugin.name, STATUS.DISABLED

Plugins = new PluginsManager

# exports
module.exports = Plugins
