# From: https://gist.github.com/contra/2759355

class EventEmitter
  constructor: ->
    @events = {}

  emit: (event, args...) ->
    # Can return a jquery-style 'false' intended to override bubbling behavior.
    # A false from any listener makes this return false, but does not halt proprogation to other listeners
    return false unless @events[event]
    retVal = true
    for listener in @events[event]
      if false == listener args...
        retVal = false
    return retVal

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
