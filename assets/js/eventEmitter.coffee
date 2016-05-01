# based on https://gist.github.com/contra/2759355

class EventEmitter
  constructor: ->
    # mapping from event to list of listeners
    @listeners = {}
    @hooks = {}

  # emit an event and return all responses from the listeners
  emit: (event, args...) ->
    ((listener event, args...) for listener in (@listeners['all'] or []))
    return ((listener args...) for listener in (@listeners[event] or []))

  addListener: (event, listener) ->
    @emit 'newListener', event, listener
    (@listeners[event]?=[]).push listener
    return @

  on: @::addListener

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

  off: @::removeListener

  # ordered set of hooks for mutating
  # NOTE: a little weird for eventEmitter to be in charge of this

  addHook: (event, transform) ->
    (@hooks[event]?=[]).push transform

  removeHook: (event, transform) ->
    return @ unless @hooks[event]
    @hooks[event] = (t for t in @hooks[event] when t isnt transform)
    return @

  applyHook: (event, obj, info) ->
    for transform in (@hooks[event] or [])
      obj = transform obj, info
    return obj

# exports
module.exports = EventEmitter
