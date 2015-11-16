if module?
  global._ = require('lodash')
  global.tv4 = require('tv4')

  global.Logger = require('./logger.coffee')
  global.errors = require('./errors.coffee')
  global.DependencyGraph = require('dependencies-online')

(() ->
  # class for exposing plugin API
  class PluginApi
    constructor: (@view, @plugin_metadata) ->
      @name = @plugin_metadata.name
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

  PLUGIN_SCHEMA = {
    title: "Plugin metadata schema"
    type: "object"
    required: [ 'name' ]
    properties: {
      name: {
        description: "Name of the plugin"
        pattern: "^[A-Za-z0-9_ ]{3,20}$"
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
      data_version: {
        description: "Version of data format for plugin"
        type: "integer"
        default: 1
        minimum: 1
      }
    }
  }

  # shim for filling in default values, with tv4
  tv4.fill_defaults = (data, schema) ->
    for prop, prop_info of schema.properties
      if prop not of data
        if 'default' of prop_info
          data[prop] = prop_info['default']

  class PluginsManager
    constructor: () ->
      @plugins = {}
      @pluginDependencies = new DependencyGraph

    validate: (plugin_metadata) ->
      if not tv4.validate(plugin_metadata, PLUGIN_SCHEMA, true, true)
        throw new errors.GenericError(
          "Error validating plugin #{JSON.stringify(plugin_metadata, null, 2)}: #{JSON.stringify(tv4.error)}"
        )
      tv4.fill_defaults plugin_metadata, PLUGIN_SCHEMA

    resolveView: (view) ->
      @view = view
      @pluginDependencies.resolve '_view', true

    load: (plugin_metadata, cb) ->
      api = new PluginApi @view, plugin_metadata

      # validate data version
      dataVersion = do api.getDataVersion
      unless dataVersion?
        api.setDataVersion plugin_metadata.data_version
        dataVersion = plugin_metadata.data_version
      # TODO: Come up with some migration system for both vimflowy and plugins
      errors.assert_equals dataVersion, plugin_metadata.data_version,
        "Plugin data versions are not identical, please contact the plugin author for migration support"

      Logger.logger.info "Plugin #{plugin_metadata.name} loading"
      cb(api)
      Logger.logger.info "Plugin #{plugin_metadata.name} loaded"

    register: (plugin_metadata, cb) ->
      @validate plugin_metadata

      @plugins[plugin_metadata.name] = plugin_metadata
      Logger.logger.info "Plugin #{plugin_metadata.name} registered"

      dependencies = _.clone (_.result plugin_metadata, 'dependencies', [])
      dependencies.push '_view'

      # Load the plugin after all its dependencies have loaded
      @pluginDependencies.add plugin_metadata.name, dependencies, () =>
        @load plugin_metadata, cb

  Plugins = new PluginsManager

  # exports
  module?.exports = Plugins
  window?.Plugins = Plugins
)()
