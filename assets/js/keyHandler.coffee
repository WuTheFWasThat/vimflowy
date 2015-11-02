###
Takes in keys, and, based on the keybindings (see keyBindings.coffee), manipulates the view (see view.coffee)

The KeyHandler class manages the state of what keys have been input, dealing with the logic for
- handling multi-key sequences, i.e. a key that semantically needs another key (e.g. the GO command, `g` in vim)
- handling motions and commands that take motions
- combining together and saving sequences of commands (important for the REPEAT command, `.` in vim, for macros, and for number prefixes, e.g. 3j)
- dropping sequences of commands that are invalid
- telling the view when to save (i.e. the proper checkpoints for undo and redo)
It maintains custom logic for this, for each mode.
(NOTE: hopefully this logic can be more unified!  It is currently quite fragile)

the KeyStream class is a helper class which deals with queuing and checkpointing a stream of key events
###

# imports
if module?
  global.EventEmitter = require('./eventEmitter.coffee')
  global.errors = require('./errors.coffee')
  global.Menu = require('./menu.coffee')
  global.constants = require('./constants.coffee')
  global.Logger = require('./logger.coffee')

(() ->
  MODES = constants.MODES

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

    forget: () ->
      dropped = @queue.splice 0, @index
      @index = 0
      return dropped

  class KeyHandler

    constructor: (view, keyBindings) ->
      @view = view

      @keyBindings = keyBindings

      @macros = {}
      @recording = {
        stream: null
        key: null
      }

      @keyStream = new KeyStream
      @keyStream.on 'save', () =>
        do @view.save

    ############
    # for macros
    ############

    beginRecording: (key) ->
      @recording.stream = new KeyStream
      @recording.key = key

    finishRecording: () ->
      macro = @recording.stream.queue
      @macros[@recording.key] = macro
      @recording.stream = null
      @recording.key = null

    playRecording: (recording) ->
      # the recording shouldn't save, (i.e. no @view.save)
      recordKeyStream = new KeyStream recording
      @processKeys recordKeyStream

    ###################
    # general handling
    ###################

    handleKey: (key) ->
      if do @view.showingSettings
          @view.handleSettings key
          return true
      Logger.logger.debug 'Handling key:', key
      @keyStream.enqueue key
      if @recording.stream
        @recording.stream.enqueue key
      handled = @processKeys @keyStream
      return handled

    # NOTE: handled tells the eventEmitter whether to preventDefault or not
    processKeys: (keyStream) ->
      handled = false
      while not keyStream.done() and not keyStream.waiting
        do keyStream.checkpoint
        handled = (@processOnce keyStream) or handled
      do @view.render
      return handled

    processOnce: (keyStream) ->
      if @view.mode == MODES.NORMAL
        return @processNormalMode keyStream
      else if @view.mode == MODES.INSERT
        return @processInsertMode keyStream
      else if @view.mode == MODES.VISUAL
        return @processVisualMode keyStream
      else if @view.mode == MODES.VISUAL_LINE
        return @processVisualLineMode keyStream
      else if @view.mode == MODES.SEARCH
        return @processSearchMode keyStream
      else if @view.mode == MODES.MARK
        return @processMarkMode keyStream
      else
        throw new errors.UnexpectedValue "mode", @view.mode

    processInsertMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw errors.GenericError 'Got no key in insert mode'
      # if key == null then return do keyStream.wait

      bindings = @keyBindings.bindings[MODES.INSERT]
      args = []

      if not (key of bindings)
        if key == 'shift+enter'
          key = '\n'
        else if key == 'space' or key == 'shift+space'
          key = ' '

        if key.length == 1
          # simply insert the key
          obj = {char: key}
          for property in constants.text_properties
            if @view.cursor.getProperty property then obj[property] = true
          @view.addCharsAtCursor [obj], {cursor: {pastEnd: true}}
          return true

        if not ('MOTION' of bindings)
          return false

        info = bindings['MOTION']

        # note: this uses original bindings to determine what's a motion
        [motion, repeat] = @getMotion keyStream, key, @keyBindings.motion_bindings[MODES.INSERT]
        if motion == null
          return false

        args.push motion
      else
        info = bindings[key]

      fn = info.definition
      context = {
        mode: MODES.INSERT
        view: @view
        keyStream: keyStream
      }
      fn.apply context, args

      return true

    processVisualMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw errors.GenericError 'Got no key in visual mode'
      # if key == null then return do keyStream.wait

      bindings = @keyBindings.bindings[MODES.VISUAL]

      args = []
      if not (key of bindings)
        if not ('MOTION' of bindings)
          do keyStream.forget
          return false

        [motion, repeat] = @getMotion keyStream, key, @keyBindings.motion_bindings[MODES.VISUAL]

        if motion == null
          if keyStream.waiting # motion continuing
            return true
          else
            do keyStream.forget
            return false

        info = bindings['MOTION']
        args.push motion
      else
        info = bindings[key]
        repeat = 1

      context = {
        mode: MODES.VISUAL
        view: @view
        keyStream: @keyStream
        repeat: repeat
      }
      info.definition.apply context, args
      return true

    processVisualLineMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw errors.GenericError 'Got no key in visual line mode'
      # if key == null then return do keyStream.wait

      bindings = @keyBindings.bindings[MODES.VISUAL_LINE]

      args = []
      if not (key of bindings)
        if not ('MOTION' of bindings)
          do keyStream.forget
          return false

        [motion, repeat] = @getMotion keyStream, key, @keyBindings.motion_bindings[MODES.VISUAL_LINE]

        if motion == null
          if keyStream.waiting # motion continuing
            return true
          else
            do keyStream.forget
            return false

        info = bindings['MOTION']
        args.push motion
      else
        info = bindings[key]
        repeat = 1

      [parent, index1, index2] = do @view.getVisualLineSelections
      # TODO: get a row, instead of id, for parent
      context = {
        mode: MODES.VISUAL_LINE
        view: @view,
        repeat: repeat,
        keyStream: @keyStream,
        row_start_i: index1
        row_end_i: index2
        row_start: (@view.data.getChildren parent)[index1]
        row_end: (@view.data.getChildren parent)[index2]
        parent: parent
        num_rows: index2 - index1 + 1
      }
      info.definition.apply context, args
      return true

    processSearchMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw errors.GenericError 'Got no key in search mode'

      bindings = @keyBindings.bindings[MODES.SEARCH]

      menu_view = @view.menu.view
      args = []

      if not (key of bindings)
        if key == 'shift+enter'
          key = '\n'
        else if key == 'space'
          key = ' '
        if key.length == 1
          menu_view.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
          do @view.menu.update
          do keyStream.forget
          return true

        if not ('MOTION' of bindings)
          return false

        [motion, repeat] = @getMotion keyStream, key, @keyBindings.motion_bindings[MODES.SEARCH]

        if motion == null
          return false
        info = bindings['MOTION']
        args.push motion
      else
        info = bindings[key]

      fn = info.definition
      context = {
        mode: MODES.SEARCH
        view: @view,
        keyStream: @keyStream
      }
      fn.apply context, args

      if @view.mode != MODES.NORMAL
        do @view.menu.update

      do keyStream.forget
      return true

    processMarkMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw errors.GenericError 'Got no key in mark mode'

      bindings = @keyBindings.bindings[MODES.MARK]

      mark_view = @view.markview

      args = []
      if not (key of bindings)
        # must be non-whitespace
        if key.length == 1
          if /^\S*$/.test(key)
            mark_view.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
            return true
          return false

        if not ('MOTION' of bindings)
          return false

        [motion, repeat] = @getMotion keyStream, key, @keyBindings.motion_bindings[MODES.MARK]

        if motion == null
          return false
        info = bindings['MOTION']
        args.push motion
      else
        info = bindings[key]

      fn = info.definition
      context = {
        mode: MODES.MARK
        view: @view
        keyStream: @keyStream
      }
      fn.apply context, args
      return true

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
    getMotion: (keyStream,
                motionKey = null,
                bindings = @keyBindings.motion_bindings[MODES.NORMAL],
                repeat = 1) =>
      [motionRepeat, motionKey] = @getRepeat keyStream, motionKey
      repeat = repeat * motionRepeat

      if motionKey == null
        do keyStream.wait
        return [null, repeat]

      if not (motionKey of bindings)
        do keyStream.forget
        return [null, repeat]

      definition = bindings[motionKey].definition
      if typeof definition == 'object'
        # recursive definition
        return (@getMotion keyStream, null, definition, repeat)
      else if typeof definition == 'function'
        context = {
          view: @view
          repeat: repeat
          keyStream: keyStream
          keyHandler: @
        }
        motion = definition.apply context, []
        return [motion, repeat]
      else
        throw new errors.UnexpectedValue "definition", definition

    processNormalMode: (keyStream, bindings = @keyBindings.bindings[MODES.NORMAL], repeat = 1) ->
      [newrepeat, key] = @getRepeat keyStream
      if key == null
        do keyStream.wait
        return true
      # TODO: something better for passing repeat through?
      repeat = repeat * newrepeat

      fn = null
      args = []

      if not (key of bindings)
        if not ('MOTION' of bindings)
          do keyStream.forget
          return false

        # note: this uses original bindings to determine what's a motion
        [motion, repeat] = @getMotion keyStream, key, @keyBindings.motion_bindings[MODES.NORMAL], repeat
        if motion == null
          if keyStream.waiting # motion continuing
            return true
          else
            do keyStream.forget
            return false

        args.push motion
        info = bindings['MOTION']
      else
        info = bindings[key] || {}

      definition = info.definition
      if typeof definition == 'object'
        # recursive definition
        return @processNormalMode keyStream, info.definition, repeat
      else if typeof definition == 'function'
        context = {
          mode: MODES.NORMAL
          view: @view
          repeat: repeat
          keyStream: keyStream
          keyHandler: @
        }
        info.definition.apply context, args
        return true
      else
        throw new errors.UnexpectedValue "definition", definition

  module?.exports = KeyHandler
  window?.KeyHandler = KeyHandler
)()
