# From: https://gist.github.com/contra/2759355

class EventEmitter
  constructor: ->
    @events = {}

  # emit an event and return all responses from the listeners
  emit: (event, args...) ->
    return ((listener args...) for listener in (@events[event] or []))

  addListener: (event, listener) ->
    @emit 'newListener', event, listener
    (@events[event]?=[]).push listener
    return @

  on: @::addListener

  once: (event, listener) ->
    fn = =>
      @removeListener event, fn
      listener arguments...
    @on event, fn
    return @

  removeListener: (event, listener) ->
    return @ unless @events[event]
    @events[event] = (l for l in @events[event] when l isnt listener)
    return @

  removeAllListeners: (event) ->
    delete @events[event]
    return @

# exports
module?.exports = EventEmitter
window?.EventEmitter = EventEmitter
