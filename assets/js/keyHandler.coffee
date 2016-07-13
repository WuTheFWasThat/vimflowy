###
Takes in keys, and, based on the keybindings (see keyBindings.coffee), manipulates the session (see session.coffee)

The KeyHandler class manages the state of what keys have been input, dealing with the logic for
- handling multi-key sequences, i.e. a key that semantically needs another key (e.g. the GO command, `g` in vim)
- handling motions and commands that take motions
- combining together and saving sequences of commands (important for the REPEAT command, `.` in vim, for macros, and for number prefixes, e.g. 3j)
- dropping sequences of commands that are invalid
- telling the session when to save (i.e. the proper checkpoints for undo and redo)
It maintains custom logic for this, for each mode.
(NOTE: hopefully this logic can be more unified!  It is currently quite fragile)

the KeyStream class is a helper class which deals with queuing and checkpointing a stream of key events
###

EventEmitter = require './eventEmitter.js'
errors = require './errors.coffee'
Menu = require './menu.coffee'
Modes = require './modes.coffee'
constants = require './constants.coffee'

Logger = require './logger.coffee'

MODES = Modes.modes

# manages a stream of keys, with the ability to
# - queue keys
# - wait for more keys
# - flush sequences of keys
# - save sequences of relevant keys
class KeyStream extends EventEmitter
  constructor: (keys = []) ->
    super

    @queue = [] # queue so that we can read group of keys, like 123 or fy
    @lastSequence = [] # last key sequence
    @index = 0
    @checkpoint_index = 0
    @waiting = false

    for key in keys
      @enqueue key

  empty: () ->
    return @queue.length == 0

  done: () ->
    return @index == @queue.length

  rewind: () ->
    @index = @checkpoint_index

  enqueue: (key) ->
    @queue.push key
    @waiting = false

  dequeue: () ->
    if @index == @queue.length then return null
    return @queue[@index++]

  checkpoint: () ->
    @checkpoint_index = @index

  # means we are waiting for another key before we can do things
  wait: () ->
    @waiting = true
    do @rewind

  save: () ->
    processed = do @forget
    @lastSequence = processed
    @emit 'save'

  # forgets the most recently processed n items
  forget: (n = null) ->
    if n == null
      # forget everything remembered, by default
      n = @index

    errors.assert (@index >= n)
    dropped = @queue.splice (@index-n), n
    @index = @index - n
    return dropped

class KeyHandler extends EventEmitter

  constructor: (session, keyBindings) ->
    @session = session

    @keyBindings = keyBindings

    @macros = do @session.document.store.getMacros
    @recording = {
      stream: null
      key: null
    }

    @keyStream = new KeyStream
    @keyStream.on 'save', () =>
      do @session.save

  ############
  # for macros
  ############

  beginRecording: (key) ->
    @recording.stream = new KeyStream
    @recording.key = key

  finishRecording: () ->
    macro = @recording.stream.queue
    @macros[@recording.key] = macro
    @session.document.store.setMacros @macros
    @recording.stream = null
    @recording.key = null

  playRecording: (recording) ->
    # the recording shouldn't save, (i.e. no @session.save)
    recordKeyStream = new KeyStream recording
    @processKeys recordKeyStream

  ###################
  # general handling
  ###################

  handleKey: (key) ->
    Logger.logger.debug 'Handling key:', key
    @keyStream.enqueue key
    if @recording.stream
      @recording.stream.enqueue key
    handled = @processKeys @keyStream
    return handled

  # NOTE: handled tells the eventEmitter whether to preventDefault or not
  #       returns whether the *last key* was handled
  processKeys: (keyStream) ->
    handled = true
    while not keyStream.done() and not keyStream.waiting
      do keyStream.checkpoint
      handled = @processOnce keyStream
      if not handled
        mode_obj = Modes.getMode @session.mode
        mode_obj.handle_bad_key keyStream
    return handled

  processOnce: (keyStream) ->
    @processMode @session.mode, keyStream

  # returns: whether we encountered a bad key
  processMode: (mode, keyStream, bindings = null, repeat = 1) ->
    if bindings == null
      bindings = @keyBindings.bindings[mode]

    context = {
      mode: mode
      session: @session
      repeat: repeat
      keyStream: keyStream
      keyHandler: @
    }

    mode_obj = Modes.getMode mode

    key = do keyStream.dequeue

    args = []

    [key, context] = mode_obj.transform_key key, context
    if key == null
      # either key was already null, or
      # a transform acted (which, for now, we always consider not bad.  could change)
      return true

    if (key of bindings)
      info = bindings[key]
    else
      if not ('MOTION' of bindings)
        return false

      # note: this uses original bindings to determine what's a motion
      [motion, context.repeat, handled] = @getMotion keyStream, key, @keyBindings.motion_bindings[mode], context.repeat
      if motion == null
        return handled

      args.push motion
      info = bindings['MOTION']

    definition = info.definition
    if typeof definition == 'object'
      # recursive definition
      return @processMode mode, keyStream, info.definition, context.repeat
    else if typeof definition == 'function'
      context = mode_obj.transform_context context
      info.definition.apply context, args
      (Modes.getMode @session.mode).every @session, keyStream
      return true
    else
      throw new errors.UnexpectedValue "definition", definition

  # NOTE: this should maybe be normal-mode specific
  #       but it would also need to be done for the motions
  # takes keyStream, key, returns repeat number and key
  getRepeat: (keyStream, key = null) ->
    if key == null
      key = do keyStream.dequeue
    begins = [1..9].map ((x) -> return do x.toString)
    continues = [0..9].map ((x) -> return do x.toString)
    if key not in begins
      return [1, key]
    numStr = key
    key = do keyStream.dequeue
    if key == null then return [null, null]
    while key in continues
      numStr += key
      key = do keyStream.dequeue
      if key == null then return [null, null]
    return [parseInt(numStr), key]

  # useful when you expect a motion
  getMotion: (keyStream, motionKey, bindings, repeat) =>
    [motionRepeat, motionKey] = @getRepeat keyStream, motionKey
    repeat = repeat * motionRepeat

    if motionKey == null
      do keyStream.wait
      return [null, repeat, true]

    if not (motionKey of bindings)
      return [null, repeat, false]

    definition = bindings[motionKey].definition
    if typeof definition == 'object'
      # recursive definition
      return (@getMotion keyStream, null, definition, repeat)
    else if typeof definition == 'function'
      context = {
        session: @session
        repeat: repeat
        keyStream: keyStream
        keyHandler: @
      }
      motion = definition.apply context, []
      return [motion, repeat, true]
    else
      throw new errors.UnexpectedValue "definition", definition


module.exports = KeyHandler
