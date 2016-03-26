if module?
  global.utils = require('./utils.coffee')

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
      every: {
        description: "Function executed on every action, while in the mode.  Takes view and keystream"
        type: "function"
      }
      exit: {
        description: "Function taking view, upon entering mode"
        type: "function"
      }

      key_transforms: {
        description: """
        a list of functions taking a key and context
          (key, context) -> [key, context]
        if the key should be ignored, return it as null (in which case
        other functions won't receive the key)

        the functions are called in the order they're registered
        """
        type: "array"
        default: []
        items: {
          type: "function"
        }
      }
      transform_context: {
        description: """
        a functions taking a context and returning a new context
        in which definition functions will be executed
        (this is called right before execution)
        """
        type: "function"
        default: ((context) -> return context)
      }
    }
  }
  class Mode
    constructor: (metadata) ->
      @metadata = metadata
      @name = metadata.name
      @key_transforms = metadata.key_transforms
      @transform_context = metadata.transform_context

    enter: (view) ->
      if @metadata.enter
        @metadata.enter view

    every: (view, keyStream) ->
      if @metadata.every
        @metadata.every view, keyStream

    exit: (view) ->
      if @metadata.exit
        @metadata.exit view

    transform_key: (key, context) ->
      for key_transform in @key_transforms
        [key, context] = key_transform key, context
        if key == null
          break
      return [key, context]

    handle_bad_key: (key, keyStream) ->
      # for normal mode types, single bad key -> forgotten sequence
      if @metadata.hotkey_type == NORMAL_MODE_TYPE
        do keyStream.forget
      return false


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
    utils.tv4_validate(metadata, MODE_SCHEMA, "mode")
    utils.fill_tv4_defaults metadata, MODE_SCHEMA

    name = metadata.name
    mode = new Mode metadata
    MODES_ENUM[name] = modeCounter
    MODES[modeCounter] = mode
    MODE_TYPES[metadata.hotkey_type].modes.push modeCounter
    modeCounter += 1
    return mode

  transform_insert_key = (key) ->
    if key == 'shift+enter'
      key = '\n'
    else if key == 'space' or key == 'shift+space'
      key = ' '
    return key

  registerMode {
    name: 'NORMAL'
    hotkey_type: NORMAL_MODE_TYPE
    enter: (view) ->
      do view.cursor.backIfNeeded
    key_transforms: [
      (key, context) ->
        [newrepeat, key] = context.keyHandler.getRepeat context.keyStream, key
        context.repeat = context.repeat * newrepeat
        if key == null
          do context.keyStream.wait
        return [key, context]
    ]
  }
  registerMode {
    name: 'INSERT'
    hotkey_type: INSERT_MODE_TYPE
    key_transforms: [
      (key, context) ->
        key = transform_insert_key key
        if key.length == 1
          # simply insert the key
          obj = {char: key}
          for property in constants.text_properties
            if context.view.cursor.getProperty property then obj[property] = true
          context.view.addCharsAtCursor [obj], {cursor: {pastEnd: true}}
          return [null, context]
        return [key, context]
    ]
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
    transform_context: (context) ->
      view = context.view
      [parent, index1, index2] = do view.getVisualLineSelections
      context.row_start_i = index1
      context.row_end_i = index2
      context.row_start = (view.data.getChildren parent)[index1]
      context.row_end = (view.data.getChildren parent)[index2]
      context.parent = parent
      context.num_rows = index2 - index1 + 1
      return context
  }
  registerMode {
    name: 'SEARCH'
    hotkey_type: INSERT_MODE_TYPE
    enter: (view) ->
      if view.menuDiv
        view.menuDiv.removeClass 'hidden'
        view.mainDiv.addClass 'hidden'
    every: (view, keyStream) ->
      do view.menu.update
      do keyStream.forget
    exit: (view) ->
      view.menu = null
      if view.menuDiv
        view.menuDiv.addClass 'hidden'
        view.mainDiv.removeClass 'hidden'
    key_transforms: [
      (key, context) ->
        key = transform_insert_key key
        if key.length == 1
          context.view.menu.view.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
          do context.view.menu.update
          do context.keyStream.forget
          return [null, context]
        return [key, context]
    ]

  }
  registerMode {
    name: 'MARK'
    hotkey_type: INSERT_MODE_TYPE
    enter: (view) ->
      # initialize marks stuff
      data = new Data (new dataStore.InMemory)
      view.markview = new View data
      view.markrow = view.cursor.row
    exit: (view) ->
      view.markview = null
      view.markrow = null
    key_transforms: [
      (key, context) ->
        # must be non-whitespace
        if key.length == 1
          if /^\S*$/.test(key)
            context.view.markview.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
            return [null, context]
        return [key, context]
    ]

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
