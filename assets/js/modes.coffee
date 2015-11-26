if module?
  global.tv4 = require('tv4')

((exports) ->

  MODE_SCHEMA = {
    title: "Mode metadata schema"
    type: "object"
    required: [ 'name' ]
    properties: {
      name: {
        description: "Name of the mode"
        pattern: "^[A-Z_]{2,32}$"
        type: "string"
      }
      description: {
        description: "Description of the mode"
        type: "string"
      }
      hotkey_type: { # TODO: get rid of this?
        description: "Either normal-like or insert-like"
        type: "string"
      }
      enter: {
        description: "Function taking view, upon entering mode"
        type: "function"
      }
      exit: {
        description: "Function taking view, upon entering mode"
        type: "function"
      }
    }
  }
  class Mode
    # TODO: set mode and unset mode hooks

    constructor: (metadata) ->
      @metadata = metadata
      @name = metadata.name

      # a list of functions taking a key and view
      #   (key, view) -> key
      # if the key should be ignored, return null (in which case
      # other functions won't receive the key)

      # the functions are called in the order they're registered
      # false if the key should be filtered out
      @key_transforms = []

    enter: (view) ->
      if @metadata.enter
        @metadata.enter view

    exit: (view) ->
      if @metadata.exit
        @metadata.exit view

  # an enum dictionary,
  MODES_ENUM = {}
  # mapping from mode name to the actual mode object
  MODES = {}
  NORMAL_MODE_TYPE = 'Normal-like modes'
  INSERT_MODE_TYPE = 'Insert-like modes'
  MODE_TYPES = {}
  MODE_TYPES[NORMAL_MODE_TYPE] = {
    description: 'Modes in which text is not being inserted, and all keys are configurable as commands.  NORMAL, VISUAL, and VISUAL_LINE modes fall under this category.'
    modes: []
  }
  MODE_TYPES[INSERT_MODE_TYPE] = {
    description: 'Modes in which most text is inserted, and available hotkeys are restricted to those with modifiers.  INSERT, SEARCH, and MARK modes fall under this category.'
    modes: []
  }

  modeCounter = 1
  registerMode = (metadata, options = {}) ->
    if not tv4.validate(metadata, MODE_SCHEMA, true, true)
      throw new errors.GenericError(
        "Error validating mode #{JSON.stringify(mode, null, 2)}: #{JSON.stringify(tv4.error)}"
      )
    name = metadata.name
    mode = new Mode metadata
    MODES_ENUM[name] = modeCounter
    MODES[modeCounter] = mode
    MODE_TYPES[metadata.hotkey_type].modes.push modeCounter
    modeCounter += 1
    return mode

  registerMode {
    name: 'NORMAL'
    hotkey_type: NORMAL_MODE_TYPE
    enter: (view) ->
      do view.cursor.backIfNeeded
  }
  registerMode {
    name: 'INSERT'
    hotkey_type: INSERT_MODE_TYPE
  }
  registerMode {
    name: 'VISUAL'
    hotkey_type: NORMAL_MODE_TYPE
    enter: (view) ->
      view.anchor = do view.cursor.clone
    exit: (view) ->
      view.anchor = null
  }
  registerMode {
    name: 'VISUAL_LINE'
    hotkey_type: NORMAL_MODE_TYPE
    enter: (view) ->
      view.anchor = do view.cursor.clone
      view.lineSelect = true
    exit: (view) ->
      view.anchor = null
      view.lineSelect = false
  }
  registerMode {
    name: 'SEARCH'
    hotkey_type: INSERT_MODE_TYPE
    enter: (view) ->
      if view.menuDiv
        view.menuDiv.removeClass 'hidden'
        view.mainDiv.addClass 'hidden'
    exit: (view) ->
      view.menu = null
      if view.menuDiv
        view.menuDiv.addClass 'hidden'
        view.mainDiv.removeClass 'hidden'
  }
  registerMode {
    name: 'MARK'
    hotkey_type: INSERT_MODE_TYPE
    enter: (view) ->
      # initialize marks stuff
      data = new Data (new dataStore.InMemory)
      data.load {
        text: ''
        children: ['']
      }
      view.markview = new View data
      view.markrow = view.cursor.row
    exit: (view) ->
      view.markview = null
      view.markrow = null
  }

  me = {
    modes: MODES_ENUM
    types: MODE_TYPES
    getMode: (mode) -> MODES[mode]
    NORMAL_MODE_TYPE: NORMAL_MODE_TYPE
    INSERT_MODE_TYPE: INSERT_MODE_TYPE
  }
  module?.exports = me
  window?.Modes = me
)()
