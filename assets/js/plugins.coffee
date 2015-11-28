if module?
  global._ = require('lodash')
  global.tv4 = require('tv4')
  global.DependencyGraph = require('dependencies-online')

  global.utils = require('./utils.coffee')
  global.Logger = require('./logger.coffee')
  global.errors = require('./errors.coffee')

(() ->
  # class for exposing plugin API
  class PluginApi
    constructor: (@view, @metadata, @pluginManager) ->
      @name = @metadata.name
      @data = @view.data
      @cursor = @view.cursor
      # TODO: Add subloggers and prefix all log messages with the plugin name
      @logger = Logger.logger

    getDataVersion: () ->
      @data.store.getPluginDataVersion @name

    setDataVersion: (version) ->
      @data.store.setPluginDataVersion @name, version

    setData: (key, value) ->
      @data.store.setPluginData @name, key, value

    getData: (key) ->
      @data.store.getPluginData @name, key

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
      dependencies: {
        description: "Dependencies of the plugin - a list of other plugins"
        type: "array"
        items: { type: "string" }
        default: []
      }
      dataVersion: {
        description: "Version of data format for plugin"
        type: "integer"
        default: 1
        minimum: 1
      }
    }
  }

  class PluginsManager

    STATUS = {
      UNREGISTERED: "Unregistered",
      REGISTERED: "Registered",
      DISABLING: "Disabling",
      ENABLING: "Enabling",
      DISABLED: "Disabled",
      ENABLED: "Enabled",
    }

    constructor: (options) ->
      # Will be overridden before plugin loading, during 'resolveView'
      @enabledPlugins = {}

      @plugins = {}
      @pluginDependencies = new DependencyGraph

    validate: (plugin_metadata) ->
      if not tv4.validate(plugin_metadata, PLUGIN_SCHEMA, true, true)
        throw new errors.GenericError(
          "Error validating plugin #{JSON.stringify(plugin_metadata, null, 2)}: #{JSON.stringify(tv4.error)}"
        )
      utils.fill_tv4_defaults plugin_metadata, PLUGIN_SCHEMA

    resolveView: (view) ->
      @view = view
      enabledPlugins = view.settings.getSetting "enabledPlugins"
      if enabledPlugins?
        @enabledPlugins = enabledPlugins
      @div = view.pluginsDiv
      do @render
      @pluginDependencies.resolve '_view', view

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
        virtualDom.h 'th', { className: 'plugin-version' }, "Version"
        virtualDom.h 'th', { className: 'plugin-name' }, "Author"
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
        virtualDom.h 'td', { className: 'center theme-trim plugin-version' }, (plugin.version + '')
        virtualDom.h 'td', { className: 'center theme-trim plugin-author' }, plugin.author
        virtualDom.h 'td', { className: 'center theme-trim plugin-status', style: {'background-color': color}}, status
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
      @enabledPlugins[name] = true
      @view.settings.setSetting "enabledPlugins", @enabledPlugins
      if (@getStatus name) == STATUS.DISABLED
        @_enable @plugins[name]

    disable: (name) ->
      delete @enabledPlugins[name]
      @view.settings.setSetting "enabledPlugins", @enabledPlugins
      if (@getStatus name) == STATUS.ENABLED
        @_disable @plugins[name]

    _disable: (plugin) ->
      # TODO: require that no other plugin has this as a dependency, notify user otherwise

      @setStatus plugin.name, STATUS.DISABLING
      api = plugin.api
      # TODO: allow disable to be async?
      plugin.disable api
      delete plugin.api
      delete plugin.value
      @setStatus plugin.name, STATUS.DISABLED

    _enable: (plugin) ->
      # TODO: require dependencies to be enabled first, notify user if not

      api = new PluginApi @view, plugin, @

      # validate data version
      dataVersion = do api.getDataVersion
      unless dataVersion?
        api.setDataVersion plugin.dataVersion
        dataVersion = plugin.dataVersion
      # TODO: Come up with some migration system for both vimflowy and plugins
      errors.assert_equals dataVersion, plugin.dataVersion,
        "Plugin data versions are not identical, please contact the plugin author for migration support"

      @setStatus plugin.name, STATUS.ENABLING
      plugin.api = api
      # TODO: allow enable to be async?
      plugin.value = plugin.enable api
      @pluginDependencies.resolve plugin.name, plugin.value
      @setStatus plugin.name, STATUS.ENABLED

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
      plugin.dependencies.push '_view'
      @setStatus plugin.name, STATUS.REGISTERED

      # Load the plugin after all its dependencies have loaded
      (@pluginDependencies.add plugin.name, plugin.dependencies).then () =>
        # TODO: handle dependency being disabled
        if plugin.name of @enabledPlugins
          @_enable plugin
        else
          @setStatus plugin.name, STATUS.DISABLED

  Plugins = new PluginsManager

  # exports
  module?.exports = Plugins
  window?.Plugins = Plugins
)()
