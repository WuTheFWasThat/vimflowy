###
Takes in keys, and, based on the keybindings, manipulates view/data
###

# imports
if module?
  EventEmitter = require('./eventEmitter.coffee')
  Menu = require('./menu.coffee')
  constants = require('./constants.coffee')

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
      @waiting = false

      for key in keys
        @enqueue key

    empty: () ->
      return @queue.length == 0

    done: () ->
      return @index == @queue.length

    rewind: () ->
      @index = 0

    enqueue: (key) ->
      @queue.push key
      @waiting = false

    dequeue: () ->
      if @index == @queue.length then return null
      return @queue[@index++]

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
      console.log('handling', key)
      @keyStream.enqueue key
      if @recording
        @recording.enqueue key
      @processKeys @keyStream

    processKeys: (keyStream) ->
      while not keyStream.done() and not keyStream.waiting
        @processOnce keyStream
      do @view.render

    processOnce: (keyStream) ->
      if @view.mode == MODES.NORMAL
        @processNormalMode keyStream
      else if @view.mode == MODES.INSERT
        @processInsertMode keyStream
      else if @view.mode == MODES.VISUAL
        @processVisualMode keyStream
      else if @view.mode == MODES.VISUAL_LINE
        @processVisualLineMode keyStream
      else if @view.mode == MODES.MENU
        @processMenuMode keyStream
      else if @view.mode == MODES.MARK
        @processMarkMode keyStream
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
        if key.length > 1
          return
        obj = {char: key}
        for property in constants.text_properties
          if @view.cursor.getProperty property then obj[property] = true
        @view.addCharsAtCursor [obj], {cursor: {pastEnd: true}}
        return

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
        return do keyStream.save

    processVisualMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in visual mode'
      # if key == null then return do keyStream.wait

      bindings = @bindings[MODES.VISUAL]

      if not (key of bindings)
        # getMotion using normal mode motions
        # TODO: make this relationship more explicit via a separate motions dictionary
        [motion, repeat] = @getMotion keyStream, key
        if motion != null

          tmp = do @view.cursor.clone # this is necessary until we figure out multiline

          for i in [1..repeat]
            motion tmp, {pastEnd: true}

          if tmp.row == @view.cursor.row # only allow same-row movement
            @view.cursor = tmp
          else
            @view.showMessage "Visual mode currently only works on one line"
        return

      info = bindings[key]

      args = []
      context = {
        view: @view,
        repeat: 1,
      }

      to_mode = null
      if info.bindings
        # this is a bit of a bad hack...
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
          do @view.cursor.backIfNeeded
          if info.drop # for yank
            return do keyStream.forget
          else
            return do keyStream.save
        else if to_mode == MODES.INSERT
          return

      return do keyStream.forget

    processVisualLineMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in visual line mode'
      # if key == null then return do keyStream.wait

      bindings = @bindings[MODES.VISUAL_LINE]

      if not (key of bindings)
        return do keyStream.forget

      info = bindings[key]

      args = []
      context = {
        view: @view,
        repeat: 1,
      }

      to_mode = null
      if info.motion
        [motion, repeat] = @getMotion keyStream, key
        if motion != null
          motion = info.fn
          for i in [1..repeat]
            motion @view.cursor, {pastEnd: true}
        return

      if info.bindings
        # this is a bit of a bad hack...
        info = info.bindings[key]

      if info.finishes_visual_line
        # set cursor to be earlier one and delete difference
        index1 = @view.data.indexOf @view.cursor.row
        index2 = @view.data.indexOf @view.anchor.row
        if index2 < index1
          @view.cursor = @view.anchor
        context.repeat = Math.abs(index2 - index1) + 1
        to_mode = if info.to_mode? then info.to_mode else MODES.NORMAL
      else
        to_mode = if info.to_mode? then info.to_mode else null

      fn = info.fn
      fn.apply context, args

      if to_mode != null
        @view.anchor = null
        @view.setMode to_mode
        @view.lineSelect = false
        if to_mode == MODES.NORMAL
          do @view.cursor.backIfNeeded
          if info.drop # for yank
            return do keyStream.forget
          else
            return do keyStream.save
        else if to_mode == MODES.INSERT
          return

      return do keyStream.forget

    processMenuMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in menu mode'

      bindings = @bindings[MODES.MENU]

      view = @menu.view

      if not (key of bindings)
        if key == 'shift+enter'
          key = '\n'
        if key.length > 1
          return
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
            menu: @menu
            repeat: 1,
          }
          fn.apply context, args

        if info.to_mode == MODES.NORMAL
          @view.setMode MODES.NORMAL

      do @menu.update
      do @menu.render
      return do keyStream.forget

    processMarkMode: (keyStream) ->
      key = do keyStream.dequeue
      if key == null then throw 'Got no key in menu mode'

      bindings = @bindings[MODES.MARK]

      view = @view.markview

      if not (key of bindings)
        # must be non-whitespace
        if key.length > 1
          return
        if /^\w*$/.test(key)
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
      return do keyStream.save

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
      if key == null then return do keyStream.wait
      # TODO: something better for passing repeat through?
      repeat = repeat * newrepeat

      fn = null
      args = []

      if not (key of bindings)
        if 'MOTION' of bindings
          info = bindings['MOTION']

          # note: this uses original bindings to determine what's a motion
          [motion, repeat] = @getMotion keyStream, key, @bindings[MODES.NORMAL], repeat
          if motion == null then return do keyStream.forget

          cursor = do @view.cursor.clone
          for i in [1..repeat]
            motion cursor, {pastEnd: true, pastEndWord: true}

          args.push cursor
        else
          return do keyStream.forget
      else
        info = bindings[key] || {}

      if info.bindings
        return @processNormalMode keyStream, info.bindings, repeat

      if info.motion
        # note: this uses *new* bindings to determine what's a motion
        [motion, repeat] = @getMotion keyStream, key, bindings, repeat
        if motion == null then return

        for j in [1..repeat]
          motion @view.cursor, ''
        return do keyStream.forget

      if info.menu
        @view.setMode MODES.MENU
        @menu = new Menu @view.menuDiv, (info.menu.bind @, @view)
        do @menu.update
        do @menu.render
        return do keyStream.forget

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
        if info.to_mode == MODES.MENU
          return do keyStream.forget
        else
          return

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
        return do keyStream.forget
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
          return do keyStream.save

      if info.name == 'REPLAY'
        for i in [1..repeat]
          newStream = new KeyStream @keyStream.lastSequence
          newStream.on 'save', () =>
            do @view.save
          @processKeys newStream
        return do keyStream.forget

      if info.drop
        return do keyStream.forget
      else
        return do keyStream.save

  module?.exports = KeyHandler
  window?.KeyHandler = KeyHandler
)()
