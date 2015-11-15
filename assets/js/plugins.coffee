if module?
  global._ = require('lodash')
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
     name: {
       required: true
       type: String
     }
     version: {
       type: Number
       default: 1
     }
     requirements: {
       type: [String]
       # a list of other plugins
       default: []
     }
     author: {
       type: String
     }
     description: {
       type: String
     }
     data_version: {
       type: Number
       default: 1
     }
  }

  class PluginsManager
    constructor: () ->
      @plugins = {}
      @pluginDependencies = new DependencyGraph

    validate: (plugin_metadata) ->
      for prop, prop_info of PLUGIN_SCHEMA
        if prop not of plugin_metadata
          if 'default' of prop_info
            plugin_metadata[prop] = prop_info['default']
          else
            throw new errors.GenericError(
              "Plugin #{plugin_metadata?.name ? "<Unnamed Plugin>"} has missing metadata field #{prop}"
            )
        else
          # TODO: validate the type?

      for prop, value of plugin_metadata
        if prop not of PLUGIN_SCHEMA
          throw new errors.GenericError(
            "Property #{prop} not valid plugin property"
          )

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

      requirements = _.clone (_.result plugin_metadata, 'requirements', [])
      requirements.push '_view'

      # Load the plugin after all its dependencies have loaded
      @pluginDependencies.add plugin_metadata.name, requirements, () =>
        @load plugin_metadata, cb

  Plugins = new PluginsManager

  # exports
  module?.exports = Plugins
  window?.Plugins = Plugins
)()
