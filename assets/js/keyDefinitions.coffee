_ = require 'lodash'

utils = require './utils.coffee'
errors = require './errors.coffee'
Modes = require './modes.coffee'

class Command
  constructor: (metadata) ->
    @metadata = metadata
    @name = metadata.name

# NOTE: this is a special command, which causes definition functions
# to always takes an extra cursor argument.
# TODO: this is a hack, and should be done more properly
# For more info/context, see keyBindings.coffee and definitions of CHANGE/DELETE/YANK
motionCommandName = 'MOTION'

class KeyDefinitions
  constructor: () ->
    @WITHIN_ROW_MOTIONS = {}
    @ALL_MOTIONS = {}

    # list of possible commands for each mode
    @commands_by_mode = {}
    for modename, mode of Modes.modes
      @commands_by_mode[mode] = []

    @defaultHotkeys = {}
    # key mappings for normal-like modes (normal, visual, visual-line)
    @defaultHotkeys[Modes.NORMAL_MODE_TYPE] = {}
    # key mappings for insert-like modes (insert, mark, menu)
    @defaultHotkeys[Modes.INSERT_MODE_TYPE] = {}

    @commands = {}

    @motions = {}

    @actions = {}
    for modename, mode of Modes.modes
      @actions[mode] = {}

  clone: () ->
    other = new KeyDefinitions
    for k in ['WITHIN_ROW_MOTIONS', 'ALL_MOTIONS', 'commands_by_mode', 'defaultHotkeys', 'commands', 'motions', 'actions']
      other[k] = _.cloneDeep @[k]
    return other

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

  registerCommand: (metadata) ->
    utils.tv4_validate(metadata, COMMAND_SCHEMA, "command")
    utils.fill_tv4_defaults(metadata, COMMAND_SCHEMA)
    name = metadata.name
    command = new Command metadata
    @commands[name] = command
    @defaultHotkeys[Modes.NORMAL_MODE_TYPE][name] =
      (_.cloneDeep metadata.default_hotkeys.all).concat(
       _.cloneDeep metadata.default_hotkeys.normal_like
      )
    @defaultHotkeys[Modes.INSERT_MODE_TYPE][name] =
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
        description: "Description of the motion, shows in HELP menu"
        type: "string"
      }
      multirow: {
        description: "Whether the motion is only for multi-row movements"
        type: "boolean"
        default: false
      }
    }
  }

  registerMotion: (commands, motion, definition) ->
    utils.tv4_validate(motion, MOTION_SCHEMA, "motion")
    utils.fill_tv4_defaults(motion, MOTION_SCHEMA)
    motion.definition = definition

    if not commands.slice?
      # commands isn't an array
      commands = [commands]

    obj = @motions
    for i in [0...commands.length-1]
      command = commands[i]

      if not motion.multirow
          @WITHIN_ROW_MOTIONS[command.name] = true
      @ALL_MOTIONS[command.name] = true

      if command.name not of obj
        throw new errors.GenericError "Motion #{command.name} doesn't exist"
      else if typeof obj[command.name] != 'object'
        throw new errors.GenericError "Motion #{command.name} has already been defined"
      obj = obj[command.name].definition

    command = commands[commands.length-1]
    if not motion.multirow
        @WITHIN_ROW_MOTIONS[command.name] = true
    @ALL_MOTIONS[command.name] = true

    # motion.name = command.name
    if command.name of obj
      throw new errors.GenericError "Motion #{command.name} has already been defined"
    obj[command.name] = motion

  ###
  The definition should have functions for each mode that it supports
  The functions will be passed contexts depending on each mode
    TODO: document these
    view:
    keyStream:
    repeat:
  It may also have, bindings:
      another (recursive) set of key definitions, i.e. a dictionary from command names to definitions
  ###

  ACTION_SCHEMA = {
    title: "Action metadata schema"
    type: "object"
    required: [ 'description' ]
    properties: {
      description: {
        description: "Description of the action, shows in HELP menu"
        type: "string"
      }
    }
  }

  registerAction: (modes, commands, action, definition) ->
    utils.tv4_validate(action, ACTION_SCHEMA, "action")
    action = _.cloneDeep action
    action.definition = definition

    if not commands.slice?
      # commands isn't an array
      commands = [commands]

    for mode in modes
      obj = @actions[mode]

      for i in [0...commands.length-1]
        command = commands[i]
        if command.name != motionCommandName
          @commands_by_mode[mode].push command.name

        if command.name not of obj
          throw new errors.GenericError "Action #{command.name} doesn't exist"
        else if typeof obj[command.name] != 'object'
          throw new errors.GenericError "Action #{command.name} has already been defined"
        obj = obj[command.name].definition

      command = commands[commands.length-1]
      if command.name != motionCommandName
        @commands_by_mode[mode].push command.name
      # motion.name = command.name
      if command.name of obj
        throw new errors.GenericError "Action #{command.name} has already been defined"
      obj[command.name] = action

####################
# COMMANDS
####################

module.exports = new KeyDefinitions
