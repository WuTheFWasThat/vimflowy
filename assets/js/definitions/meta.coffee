if module?
  global.Modes = require('../modes.coffee')
  global.keyDefinitions= require('../keyDefinitions.coffee')

(() ->
  MODES = Modes.modes

  CMD_UNDO = keyDefinitions.registerCommand {
    name: 'UNDO'
    default_hotkeys:
      normal_like: ['u']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_UNDO, {
    description: 'Undo',
  }, () ->
    for i in [1..@repeat]
      do @view.undo
    do @keyStream.forget

  CMD_REDO = keyDefinitions.registerCommand {
    name: 'REDO'
    default_hotkeys:
      normal_like: ['ctrl+r']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_REDO, {
    description: 'Redo',
  }, () ->
    for i in [1..@repeat]
      do @view.redo
    do @keyStream.forget

  CMD_REPLAY = keyDefinitions.registerCommand {
    name: 'REPLAY'
    default_hotkeys:
      normal_like: ['.']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_REPLAY, {
    description: 'Replay last command',
  }, () ->
    for i in [1..@repeat]
      @keyHandler.playRecording @keyStream.lastSequence
      do @view.save
    do @keyStream.forget

  CMD_RECORD_MACRO = keyDefinitions.registerCommand {
    name: 'RECORD_MACRO'
    default_hotkeys:
      normal_like: ['q']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_RECORD_MACRO, {
    description: 'Begin/stop recording a macro',
  }, () ->
    if @keyHandler.recording.stream == null
      key = do @keyStream.dequeue
      if key == null then return do @keyStream.wait
      @keyHandler.beginRecording key
    else
      # pop off the RECORD_MACRO itself
      do @keyHandler.recording.stream.queue.pop
      do @keyHandler.finishRecording
    do @keyStream.forget

  CMD_PLAY_MACRO = keyDefinitions.registerCommand {
    name: 'PLAY_MACRO'
    default_hotkeys:
      normal_like: ['@']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_PLAY_MACRO, {
    description: 'Play a macro',
  }, () ->
    key = do @keyStream.dequeue
    if key == null then return do @keyStream.wait
    recording = @keyHandler.macros[key]
    if recording == undefined then return do @keyStream.forget
    for i in [1..@repeat]
      @keyHandler.playRecording recording
    # save the macro-playing sequence itself
    do @keyStream.save

)()
