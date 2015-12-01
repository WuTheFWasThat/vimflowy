if module?
  global.utils= require('./utils.coffee')

  global.errors = require('./errors.coffee')
  global.Modes = require('./modes.coffee')

###
keyDefinitions defines the set of possible commands.
Each command has a name, which the keyDefinitions dictionary maps to a definition,
which describes what the command should do in various modes.

Each definition has the following required fields:
    description:
        a string used for description in keybindings help screen
The definition should have functions for each mode that it supports
The functions will be passed contexts depending on each mode
  TODO: document these
  view:
  keyStream:
  repeat:
It may also have, bindings:
    another (recursive) set of key definitions, i.e. a dictionary from command names to definitions

NOTE: there is a special command called 'MOTION', which is used in the bindings dictionaries
    much like if the motion boolean is true, this command always takes an extra cursor argument.
    TODO: this is a hack, and should be done more properly

For more info/context, see keyBindings.coffee
###

((exports) ->
  MODES = Modes.modes

  NORMAL_MODE_TYPE = Modes.NORMAL_MODE_TYPE
  INSERT_MODE_TYPE = Modes.INSERT_MODE_TYPE

  WITHIN_ROW_MOTIONS = {}
  ALL_MOTIONS = {}

  # set of possible commands for each mode
  commands_by_mode = {}
  for modename, mode of MODES
    commands_by_mode[mode] = []

  defaultHotkeys = {}

  # key mappings for normal-like modes (normal, visual, visual-line)
  defaultHotkeys[NORMAL_MODE_TYPE] = {}
  # key mappings for insert-like modes (insert, mark, menu)
  defaultHotkeys[INSERT_MODE_TYPE] = {}

  COMMAND_SCHEMA = {
    title: "Command metadata schema"
    type: "object"
    required: [ 'name' ]
    properties: {
      name: {
        description: "Name of the command"
        type: "string"
        pattern: "^[A-Z_]{2,32}$"
      }
      description: {
        description: "Description of the command"
        type: "string"
      }
      default_hotkeys: {
        description: "Default hotkeys for the command"
        type: "object"
        properties: {
          all: {
            description: "Default hotkeys for all modes"
            type: "array"
            default: []
            items: { type: "string" }
          }
          normal_like: {
            description: "Default hotkey for normal-like modes"
            type: "array"
            default: []
            items: { type: "string" }
          }
          insert_like: {
            description: "Default hotkey for insert-like modes"
            type: "array"
            default: []
            items: { type: "string" }
          }
        }
      }
    }
  }

  class Command
    constructor: (metadata) ->
      @metadata = metadata
      @name = metadata.name

  commands = {}

  registerCommand = (metadata) ->
    utils.tv4_validate(metadata, COMMAND_SCHEMA, "command")
    utils.fill_tv4_defaults(metadata, COMMAND_SCHEMA)
    name = metadata.name
    command = new Command metadata
    commands[name] = command
    defaultHotkeys[NORMAL_MODE_TYPE][name] =
      (_.cloneDeep metadata.default_hotkeys.all).concat(
       _.cloneDeep metadata.default_hotkeys.normal_like
      )
    defaultHotkeys[INSERT_MODE_TYPE][name] =
      (_.cloneDeep metadata.default_hotkeys.all).concat(
       _.cloneDeep metadata.default_hotkeys.insert_like
      )
    return command

  # MOTIONS
  # should have a fn, returns a motion fn (or null)
  # the motion itself should take a cursor, and an options dictionary
  # (it should presumably move the cursor, somehow)
  # options include:
  #     pastEnd: whether to allow going past the end of the line
  #     pastEndWord: whether we consider the end of a word to be after the last letter

  MOTION_SCHEMA = {
    title: "Motion metadata schema"
    type: "object"
    required: [ 'description' ]
    properties: {
      description: {
        description: "Description of the motion"
        type: "string"
      }
      multirow: {
        description: "Whether the motion is only for multi-row movements"
        type: "boolean"
        default: false
      }
    }
  }

  motionDefinitions = {}

  registerMotion = (commands, motion, definition) ->
    utils.tv4_validate(motion, MOTION_SCHEMA, "motion")
    utils.fill_tv4_defaults(motion, MOTION_SCHEMA)
    motion.definition = definition

    if not commands.slice?
      # commands isn't an array
      commands = [commands]

    obj = motionDefinitions
    for i in [0...commands.length-1]
      command = commands[i]

      if not motion.multirow
          WITHIN_ROW_MOTIONS[command.name] = true
      ALL_MOTIONS[command.name] = true

      if command.name not of obj
        throw new errors.GenericError "Motion #{command.name} doesn't exist"
      else if typeof obj[command.name] != 'object'
        throw new errors.GenericError "Motion #{command.name} has already been defined"
      obj = obj[command.name].definition

    command = commands[commands.length-1]
    if not motion.multirow
        WITHIN_ROW_MOTIONS[command.name] = true
    ALL_MOTIONS[command.name] = true

    # motion.name = command.name
    if command.name of obj
      throw new errors.GenericError "Motion #{command.name} has already been defined"
    obj[command.name] = motion

  # TODO: make sure that the default hotkeys accurately represents the set of possible commands under that mode_type
  #       the following used to work, and should be replaced
  # for mode_type, mode_type_obj of MODE_TYPES
  #   errors.assert_arrays_equal(
  #     _.keys(defaultHotkeys[mode_type]),
  #     _.union.apply(_, mode_type_obj.modes.map((mode) -> commands_by_mode[mode]))
  #   )

  ACTION_SCHEMA = {
    title: "Action metadata schema"
    type: "object"
    required: [ 'description' ]
    properties: {
      description: {
        description: "Description of the action"
        type: "string"
      }
    }
  }

  actionDefinitions = {}
  for modename, mode of MODES
    actionDefinitions[mode] = {}

  registerAction = (modes, commands, action, definition) ->
    utils.tv4_validate(action, ACTION_SCHEMA, "action")
    action = _.cloneDeep action
    action.definition = definition

    if not commands.slice?
      # commands isn't an array
      commands = [commands]

    for mode in modes
      obj = actionDefinitions[mode]

      for i in [0...commands.length-1]
        command = commands[i]
        if command.name != 'MOTION'
          commands_by_mode[mode].push command.name

        if command.name not of obj
          throw new errors.GenericError "Action #{command.name} doesn't exist"
        else if typeof obj[command.name] != 'object'
          throw new errors.GenericError "Action #{command.name} has already been defined"
        obj = obj[command.name].definition

      command = commands[commands.length-1]
      if command.name != 'MOTION'
        commands_by_mode[mode].push command.name
      # motion.name = command.name
      if command.name of obj
        throw new errors.GenericError "Action #{command.name} has already been defined"
      obj[command.name] = action

  ####################
  # COMMANDS
  ####################

  me = {
    commands: commands
    commands_by_mode: commands_by_mode
    actions: actionDefinitions
    motions: motionDefinitions
    defaultHotkeys: defaultHotkeys
    registerCommand: registerCommand
    registerMotion: registerMotion
    registerAction: registerAction
    ALL_MOTIONS: ALL_MOTIONS
    WITHIN_ROW_MOTIONS: WITHIN_ROW_MOTIONS
  }
  module?.exports = me
  window?.keyDefinitions = me
)()
