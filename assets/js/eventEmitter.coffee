# From: https://gist.github.com/contra/2759355

class EventEmitter
  constructor: ->
    # mapping from event to list of listeners
    @listeners = {}

  # emit an event and return all responses from the listeners
  emit: (event, args...) ->
    ((listener event, args...) for listener in (@listeners['all'] or []))
    return ((listener args...) for listener in (@listeners[event] or []))

  addListener: (event, listener) ->
    @emit 'newListener', event, listener
    (@listeners[event]?=[]).push listener
    return @

  addListenerForAll: (listener) ->
    @addListener 'all', listener

  on: @::addListener
  onAll: @::addListenerForAll

  once: (event, listener) ->
    fn = =>
      @removeListener event, fn
      listener arguments...
    @on event, fn
    return @

  removeListener: (event, listener) ->
    return @ unless @listeners[event]
    @listeners[event] = (l for l in @listeners[event] when l isnt listener)
    return @

  removeAllListeners: (event) ->
    delete @listeners[event]
    return @

# exports
module?.exports = EventEmitter
window?.EventEmitter = EventEmitter
