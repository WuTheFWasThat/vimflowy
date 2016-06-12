utils = require './utils.coffee'
constants = require './constants.coffee'
Document = (require './document.coffee').Document
DataStore = require './datastore.coffee'

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
    within_row: {
      description: "Only within-row motions are supported"
      type: "boolean"
    }
    enter: {
      description: "Function taking session, upon entering mode"
      type: "function"
    }
    every: {
      description: "Function executed on every action, while in the mode.  Takes session and keystream"
      type: "function"
    }
    exit: {
      description: "Function taking session, upon entering mode"
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

  enter: (session) ->
    if @metadata.enter
      @metadata.enter session

  every: (session, keyStream) ->
    if @metadata.every
      @metadata.every session, keyStream

  exit: (session) ->
    if @metadata.exit
      @metadata.exit session

  transform_key: (key, context) ->
    for key_transform in @key_transforms
      [key, context] = key_transform key, context
      if key == null
        break
    return [key, context]

  handle_bad_key: (keyStream) ->
    # for normal mode types, single bad key -> forgotten sequence
    if @metadata.hotkey_type == NORMAL_MODE_TYPE
      do keyStream.forget
    else
      keyStream.forget 1


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
registerMode = (metadata) ->
  utils.tv4_validate(metadata, MODE_SCHEMA, "mode")
  utils.fill_tv4_defaults metadata, MODE_SCHEMA

  name = metadata.name
  # if name of MODES_ENUM
  #   # NOTE: re-registration of the mode currently happens in unit tests
  #   #       not sure why, but marks tests fail when not letting it re-register
  #   # TODO figure this out better.  also tests shouldn't keep registering new modes anyways
  #   return MODES[MODES_ENUM[name]]
  mode = new Mode metadata
  MODES_ENUM[name] = modeCounter
  MODES[modeCounter] = mode
  MODE_TYPES[metadata.hotkey_type].modes.push modeCounter
  modeCounter += 1
  return mode

deregisterMode = (mode) ->
  modeCounter = MODES_ENUM[mode.name]
  delete MODES_ENUM[mode.name]
  delete MODES[modeCounter]
  index = MODE_TYPES[mode.metadata.hotkey_type].modes.indexOf modeCounter
  MODE_TYPES[mode.metadata.hotkey_type].modes.splice index, 1

transform_insert_key = (key) ->
  if key == 'shift+enter'
    key = '\n'
  else if key == 'space' or key == 'shift+space'
    key = ' '
  return key

registerMode {
  name: 'NORMAL'
  hotkey_type: NORMAL_MODE_TYPE
  enter: (session) ->
    do session.cursor.backIfNeeded
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
          if context.session.cursor.getProperty property then obj[property] = true
        context.session.addCharsAtCursor [obj]
        return [null, context]
      return [key, context]
  ]
}

registerMode {
  name: 'VISUAL'
  hotkey_type: NORMAL_MODE_TYPE
  enter: (session) ->
    session.anchor = do session.cursor.clone
  exit: (session) ->
    session.anchor = null
}

registerMode {
  name: 'VISUAL_LINE'
  hotkey_type: NORMAL_MODE_TYPE
  enter: (session) ->
    session.anchor = do session.cursor.clone
    session.lineSelect = true
  exit: (session) ->
    session.anchor = null
    session.lineSelect = false
  transform_context: (context) ->
    session = context.session
    [parent, index1, index2] = do session.getVisualLineSelections
    context.row_start_i = index1
    context.row_end_i = index2
    context.row_start = (session.document.getChildren parent)[index1]
    context.row_end = (session.document.getChildren parent)[index2]
    context.parent = parent
    context.num_rows = index2 - index1 + 1
    return context
}

registerMode {
  name: 'SETTINGS'
  hotkey_type: NORMAL_MODE_TYPE
  enter: (session, oldmode) ->
    if session.settings.mainDiv
      session.settings.mainDiv.removeClass 'hidden'
      $('#settings-open').addClass 'hidden'
      $('#settings-close').removeClass 'hidden'
  exit: (session) ->
    if session.settings.mainDiv
      session.settings.mainDiv.addClass 'hidden'
      $('#settings-open').removeClass 'hidden'
      $('#settings-close').addClass 'hidden'
  # TODO: exit settings on any bad key press?
}

registerMode {
  name: 'SEARCH'
  hotkey_type: INSERT_MODE_TYPE
  within_row: true,
  enter: (session) ->
    if session.menuDiv
      session.menuDiv.removeClass 'hidden'
      session.mainDiv.addClass 'hidden'
  every: (session, keyStream) ->
    do session.menu.update
    do keyStream.forget
  exit: (session) ->
    session.menu = null
    if session.menuDiv
      session.menuDiv.addClass 'hidden'
      session.mainDiv.removeClass 'hidden'
  key_transforms: [
    (key, context) ->
      key = transform_insert_key key
      if key.length == 1
        context.session.menu.session.addCharsAtCursor [{char: key}]
        do context.session.menu.update
        do context.keyStream.forget
        return [null, context]
      return [key, context]
  ]
}

module.exports = {
  registerMode: registerMode
  deregisterMode: deregisterMode
  modes: MODES_ENUM
  types: MODE_TYPES
  getMode: (mode) -> MODES[mode]
  NORMAL_MODE_TYPE: NORMAL_MODE_TYPE
  INSERT_MODE_TYPE: INSERT_MODE_TYPE
}
