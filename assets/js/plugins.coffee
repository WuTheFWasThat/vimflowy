if module?
  global._ = require('lodash')
  global.Logger = require('./logger.coffee')

(() ->
  class PluginAPI
    constructor: (@view) ->
      @plugins = {}
      @pluginClass = {}
      @metadata = {}

    registerPlugin: (plugin) ->
      metadata = plugin.metadata
      # Validate metadata before accepting registration
      unless metadata?
        throw "Plugin is missing all metadata"
      required_props = ['name', 'version', 'stores_data']
      if (_.result metadata, 'stores_data')
        required_props.push 'data_version'
      for prop in ['name', 'version', 'stores_data']
        unless _.has metadata, prop
          throw "Plugin #{plugin?.name ? "<Unnamed Plugin"} has missing metadata field #{prop}"

      Logger.logger.info "Plugin #{plugin.name} registered"
      @metadata[plugin.name] = plugin.metadata
      @pluginClass[plugin.name] = plugin
      if @canLoad plugin.name
        @loadPlugin plugin.name

    # This is purely a debugging method, to make sure all the plugins that get registered get 
    finalizeRegistration: () ->
      for unloaded in (do @unloadedPlugins)
        Logger.logger.info "Plugin #{unloaded} could not be loaded"
        throw new Error "Plugin #{unloaded} could not be loaded"
      @registerPlugin = (plugin) -> throw new Error "Attempted to register plugin #{plugin?.name ? "<Unnamed plugin>"} after finalization"

    isPluginLoaded: (name) ->
      @plugins[name]?

    loadPlugin: (name) -> # TODO: Factor out dependency graph stuff into its own file, that doesn't belong here
      unless @plugins[name]?
        Logger.logger.info "Plugin #{name} loaded"
        @plugins[name] = new @pluginsClass[name] @
      for unloaded in (do @unloadedPlugins)
        if @canLoad unloaded
          @loadPlugin unloaded

    unloadedPlugins: () ->
      (name for name in @plugins unless @isPluginLoaded name)

    canLoad: (name) ->
      for requirement in (_.result @metadata[name], 'requirements', [])
        unless @requirementMet requirement
          return false
      return true
    requirementMet: (req) ->
      if typeof req == 'string'
        @isPluginLoaded req
      else
        throw new Error "Invalid requirement"

  # exports
  module?.exports = PluginAPI
  window?.PluginAPI = PluginAPI
)()
