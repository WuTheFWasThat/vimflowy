if module?
  global._ = require('lodash')
  global.Logger = require('./logger.coffee')
  global.DependencyGraph = require('dependencies-online')

(() ->
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
        Logger.logger.info "Plugin #{plugin.name} loaded"
        @plugins[plugin.name] = new @pluginClass[plugin.name] @

  # exports
  module?.exports = PluginAPI
  window?.PluginAPI = PluginAPI
)()
