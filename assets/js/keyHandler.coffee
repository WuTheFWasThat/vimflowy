###
Takes in keys, and, based on the keybindings, manipulates view/data
###

# imports
if module?
  EventEmitter = require('./eventEmitter.coffee')
  Menu = require('./menu.coffee')
  constants = require('./constants.coffee')
  Logger = require('./logger.coffee')

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

    constructor: (view, bindings) ->
      @view = view

      @bindings = bindings

      @macros = {}
      @recording = null
      @recording_key = null

      @keyStream = new KeyStream
      @keyStream.on 'save', () =>
        do @view.save

    handleKey: (key) ->
      if do @view.showingSettings
          @view.handleSettings key
          return true
      Logger.logger.debug 'Handling key:', key
      @keyStream.enqueue key
      if @recording
        @recording.enqueue key
      handled = @processKeys @keyStream
      return handled

    processKeys: (keyStream) ->
      handled = false
      while not keyStream.done() and not keyStream.waiting
        do keyStream.checkpoint
        handled = (@processOnce keyStream) or handled
      # TODO: stop re-rendering everything every time?
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
        throw "Invalid mode #{@view.mode}"

    processInsertMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in insert mode'
      # if key == null then return do keyStream.wait

      bindings = @bindings[MODES.INSERT]

      if not (key of bindings)
        if key == 'shift+enter'
          key = '\n'
        else if key == 'space'
          key = ' '
        if key.length > 1
          return false
        obj = {char: key}
        for property in constants.text_properties
          if @view.cursor.getProperty property then obj[property] = true
        @view.addCharsAtCursor [obj], {cursor: {pastEnd: true}}
        return true

      info = bindings[key]

      if info.motion
        motion = info.fn
        motion @view.cursor, {pastEnd: true}
      else if info.fn
        fn = info.fn
        args = [{cursor: {pastEnd: true}}]
        context = {
          view: @view,
          repeat: 1,
        }
        fn.apply context, args

      if info.to_mode == MODES.NORMAL
        do @view.cursor.left
        @view.setMode MODES.NORMAL
        do keyStream.save
      return true

    processVisualMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in visual mode'
      # if key == null then return do keyStream.wait

      bindings = @bindings[MODES.VISUAL]

      if not (key of bindings)
        # getMotion using normal mode motions
        # TODO: make this relationship more explicit via a separate motions dictionary
        [motion, repeat] = @getMotion keyStream, key
        if motion == null
          if keyStream.waiting # motion continuing
            return true
          else
            do keyStream.forget
            return false

        # this is necessary until we figure out multiline
        tmp = do @view.cursor.clone

        for i in [1..repeat]
          motion tmp, {pastEnd: true}

        if tmp.row != @view.cursor.row # only allow same-row movement
          @view.showMessage "Visual mode currently only works on one line"
          return true
        @view.cursor.from tmp
        return true

      info = bindings[key]

      args = []
      context = {
        view: @view,
        repeat: 1,
      }

      to_mode = null
      if info.bindings
        # TODO this is a terrible hack... for d,c,y
        info = info.bindings['MOTION']

      if info.finishes_visual
        args.push @view.anchor, {includeEnd: true}
        to_mode = if info.to_mode? then info.to_mode else MODES.NORMAL
      else
        to_mode = if info.to_mode? then info.to_mode else null

      fn = info.fn
      fn.apply context, args

      if to_mode != null
        @view.anchor = null
        @view.setMode to_mode
        if to_mode == MODES.NORMAL
          if info.drop # for yank
            do keyStream.forget
            return true
          else
            do keyStream.save
            return true
        else if to_mode == MODES.INSERT
          return true

      do keyStream.forget
      return true

    processVisualLineMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in visual line mode'
      # if key == null then return do keyStream.wait

      bindings = @bindings[MODES.VISUAL_LINE]

      if not (key of bindings)
        # getMotion using normal mode motions
        # TODO: make this relationship more explicit via a separate motions dictionary
        [motion, repeat] = @getMotion keyStream, key
        if motion == null
          if keyStream.waiting # motion continuing
            return true
          else
            do keyStream.forget
            return false

        for i in [1..repeat]
          motion @view.cursor, {pastEnd: true}
        return true

      info = bindings[key]

      args = []
      context = {
        view: @view,
        repeat: 1,
      }

      to_mode = null

      if info.bindings
        # TODO this is a terrible hack... for d,c,y
        info = info.bindings[key]

      if info.finishes_visual_line
        [parentid, index1, index2] = do @view.getVisualLineSelections
        # NOTE: this is bad (inconsistent with other behavior) for yank/indent because it moves the cursor
        # maybe just move it back afterwards?
        @view.cursor.setRow (@view.data.getChildren parentid)[index1]
        context.repeat = index2 - index1 + 1

        to_mode = if info.to_mode? then info.to_mode else MODES.NORMAL
      else
        to_mode = if info.to_mode? then info.to_mode else null

      fn = info.fn
      fn.apply context, args

      if to_mode != null
        @view.setMode to_mode

      if @view.mode != MODES.VISUAL_LINE
        if @view.mode == MODES.NORMAL
          if info.drop # for yank
            do keyStream.forget
            return true
          else
            do keyStream.save
            return true
        else if @view.mode == MODES.INSERT
          return true
      else
        do keyStream.forget
        return true

    processSearchMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in search mode'

      bindings = @bindings[MODES.SEARCH]

      view = @view.menu.view

      if not (key of bindings)
        if key == 'shift+enter'
          key = '\n'
        else if key == 'space'
          key = ' '
        if key.length > 1
          return false
        view.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
      else
        info = bindings[key]

        if info.motion
          motion = info.fn
          motion view.cursor, {pastEnd: true}
        else if info.fn
          fn = info.fn
          args = []
          context = {
            view: view,
            menu: @view.menu,
            repeat: 1,
          }
          fn.apply context, args

        if info.to_mode == MODES.NORMAL
          @view.setMode MODES.NORMAL
          return true

      do @view.menu.update
      do keyStream.forget
      return true

    processMarkMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in search mode'

      bindings = @bindings[MODES.MARK]

      view = @view.markview

      if not (key of bindings)
        # must be non-whitespace
        if key.length > 1
          return false
        if /^\S*$/.test(key)
          view.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
      else
        info = bindings[key]

        if info.motion
          motion = info.fn
          motion view.cursor, {pastEnd: true}
        else if info.fn
          fn = info.fn
          args = []
          context = {
            view: view
            original_view: @view # hack for now
            repeat: 1
          }
          fn.apply context, args

        if info.to_mode == MODES.NORMAL
          @view.markview = null
          @view.markrow = null
          @view.setMode MODES.NORMAL

      # no harm in saving.  important for setMark, and nothing else does anything
      do keyStream.save
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
    getMotion: (keyStream, motionKey, bindings = @bindings[MODES.NORMAL], repeat = 1) =>
      [motionRepeat, motionKey] = @getRepeat keyStream, motionKey
      repeat = repeat * motionRepeat

      if motionKey == null
        do keyStream.wait
        return [null, repeat]

      info = bindings[motionKey] || {}
      if not info.motion
        do keyStream.forget
        return [null, repeat]

      fn = null

      if info.continue
        key = do keyStream.dequeue
        if key == null
          do keyStream.wait
          if info.fn # bit of a hack, for easy-motion
            info.fn.apply {view: @view}
          return [null, repeat]
        fn = info.continue.bind @, key
      else if info.bindings
        answer = (@getMotion keyStream, null, info.bindings, repeat)
        return answer
      else if info.fn
        fn = info.fn

      return [fn, repeat]

    processNormalMode: (keyStream, bindings = @bindings[MODES.NORMAL], repeat = 1) ->
      [newrepeat, key] = @getRepeat keyStream
      if key == null
        do keyStream.wait
        return true
      # TODO: something better for passing repeat through?
      repeat = repeat * newrepeat

      fn = null
      args = []

      if not (key of bindings)
        if 'MOTION' of bindings
          info = bindings['MOTION']

          # note: this uses original bindings to determine what's a motion
          [motion, repeat] = @getMotion keyStream, key, @bindings[MODES.NORMAL], repeat
          if motion == null
            do keyStream.forget
            return false

          cursor = do @view.cursor.clone
          for i in [1..repeat]
            motion cursor, {pastEnd: true, pastEndWord: true}

          args.push cursor
        else
          do keyStream.forget
          return false
      else
        info = bindings[key] || {}

      if info.bindings
        return @processNormalMode keyStream, info.bindings, repeat

      if info.motion
        # note: this uses *new* bindings to determine what's a motion
        [motion, repeat] = @getMotion keyStream, key, bindings, repeat
        if motion == null
          return true

        for j in [1..repeat]
          motion @view.cursor, ''
        do keyStream.forget
        return true

      if info.menu
        @view.setMode MODES.SEARCH
        @view.menu = new Menu @view.menuDiv, (info.menu.bind @, @view)
        do @view.menu.update
        do keyStream.forget
        return true

      if info.continue
        key = do keyStream.dequeue
        if key == null then return do keyStream.wait

        fn = info.continue
        args.push key
      else if info.fn
        fn = info.fn

      if fn
        context = {
          view: @view,
          repeat: repeat,
        }
        fn.apply context, args

      if info.to_mode
        @view.setMode info.to_mode
        if info.to_mode == MODES.SEARCH
          do keyStream.forget
        return true

      if info.name == 'RECORD_MACRO'
        if @recording == null
          nkey = do keyStream.dequeue
          if nkey == null then return do keyStream.wait
          @recording = new KeyStream
          @recording_key = nkey
        else
          macro = @recording.queue
          do macro.pop # pop off the RECORD_MACRO itself
          @macros[@recording_key] = macro
          @recording = null
          @recording_key = null
        do keyStream.forget
        return true
      if info.name == 'PLAY_MACRO'
          nkey = do keyStream.dequeue
          if nkey == null then return do keyStream.wait
          recording = @macros[nkey]
          if recording == undefined then return do keyStream.forget

          for i in [1..repeat]
            # the recording shouldn't save, (i.e. no @view.save)
            recordKeyStream = new KeyStream recording
            @processKeys recordKeyStream
          # but we should save the macro-playing sequence itself
          do keyStream.save
          return true

      if info.name == 'REPLAY'
        for i in [1..repeat]
          newStream = new KeyStream @keyStream.lastSequence
          newStream.on 'save', () =>
            do @view.save
          @processKeys newStream
        do keyStream.forget
        return true

      if info.drop
        do keyStream.forget
      else
        do keyStream.save
      return true

  module?.exports = KeyHandler
  window?.KeyHandler = KeyHandler
)()
