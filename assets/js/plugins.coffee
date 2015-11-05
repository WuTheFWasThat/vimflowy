if module?
  global._ = require('lodash')
  global.Logger = require('./logger.coffee')
  global.DependencyGraph = require('dependencies-online')

(() ->
  class PluginDatabaseAccess
    constructor: (@data, @pluginName) ->

    getVersion: () ->
      @data.store.getPluginVersion @pluginName
    setVersion: (version) ->
      @data.store.setPluginVersion @pluginName, version
    setRowData: (row, args...) ->
      if args.length == 1
        [key, [data]] = ['data', args]
      else if args.length == 2
        [key, data] = args
      @data.store.setPluginRowData @pluginName, row.id, key, data
    getRowData: (row, key='data') ->
      @data.store.getPluginRowData @pluginName, row.id, key
    setGlobalData: (key, args...) ->
      if args.length == 1
        [key, [data]] = ['data', args]
      else if args.length == 2
        [key, data] = args
      @data.store.setPluginGlobalData @pluginName, key, data
    getGlobalData: (key='data') ->
      @data.store.getPluginGlobalData @pluginName, key

    transformRowData: (row, args...) ->
      if args.length == 1
        [key, [transform]] = ['data', args]
      else if args.length == 2
        [key, transform] = args
      @setRowData row, (transform (@getRowData row))
    transformGlobalData: (args...) ->
      if args.length == 1
        [key, [transform]] = ['data', args]
      else if args.length == 2
        [key, transform] = args
      @setGlobalData key, (transform (do @getGlobalData))
  
  class PluginAPI
    constructor: (@view) ->
      @plugins = {}
      @pluginClass = {}
      @metadata = {}
      @pluginDependencies = new DependencyGraph()
      # Convenience accessors
      @cursor = @view.cursor

    registerPlugin: (plugin) ->
      # Validate metadata before accepting registration
      metadata = plugin.metadata
      unless metadata?
        throw "Plugin is missing all metadata"
      required_props = ['name', 'version', 'stores_data']
      if (_.result metadata, 'stores_data')
        required_props.push 'data_version'
      for prop in ['name', 'version', 'stores_data']
        unless _.has metadata, prop
          throw "Plugin #{plugin?.name ? "<Unnamed Plugin"} has missing metadata field #{prop}"

      Logger.logger.info "Plugin #{plugin.name} registered"
      # Store the parts of the plugin in case we want to register them later
      @metadata[plugin.name] = plugin.metadata
      @pluginClass[plugin.name] = plugin
      requirements = _.result plugin.metadata, 'requirements', []
      # Load the plugin after all its dependencies have loaded
      @pluginDependencies.add plugin.name, requirements, () =>
        Logger.logger.info "Plugin #{plugin.name} loading"
        @_currentlyRegistering = plugin.name
        @plugins[plugin.name] = new @pluginClass[plugin.name] @
        delete @_currentlyRegistering
        @plugins[plugin.name]._metadata = @metadata[plugin.name]

        Logger.logger.info "Plugin #{plugin.name} loading"


    # Should be called during initialization
    getDatabase: (plugin) ->
      plugin ?= @_currentlyRegistering
      access = new PluginDatabaseAccess @view.data, plugin
      dataVersion = do access.getVersion
      pluginVersion = @metadata[plugin].version
      unless dataVersion?
        access.setVersion pluginVersion
        dataVersion = do access.getVersion
      errors.assert_equals dataVersion, pluginVersion, "Plugin data versions are not identical, please contact the plugin author for migration support" # TODO: Come up with some migration system for both vimflowy and plugins
      return access

    getLogger: (plugin) ->
      plugin ?= @_currentlyRegistering
      Logger.logger # TODO: Add subloggers and prefix all log messages with the plugin name

  # exports
  module?.exports = PluginAPI
  window?.PluginAPI = PluginAPI
)()
