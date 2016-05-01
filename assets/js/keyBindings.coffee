# imports
_ = require 'lodash'

utils = require './utils.coffee'
Modes = require './modes.coffee'
errors = require './errors.coffee'
Logger = require './logger.coffee'
EventEmitter = require './eventEmitter.coffee'

###
Terminology:
      key       - a key corresponds to a keypress, including modifiers/special keys
      command   - a command is a semantic event (see keyDefinitions.coffee)
      mode      - same as vim's notion of modes.  each mode determines the set of possible commands, and a new set of bindings
      mode type - there are two mode types: insert-like and normal-like.  Each mode falls into precisely one of these two categories.
                  'insert-like' describes modes in which typing characters inserts the characters.
                  Thus the only keys configurable as commands are those with modifiers.
                  'normal-like' describes modes in which the user is not typing, and all keys are potential commands.

The Keybindings class is primarily responsible for dealing with hotkeys
Given a hotkey mapping, it combines it with key definitions to create a bindings dictionary,
also performing some validation on the hotkeys.
Concretely, it exposes 2 main objects:
      hotkeys:
          a 2-layered mapping.  For each mode type and command name, contains a list of keys
          this is the object the user can configure
      bindings:
          another 2-layer mapping.  For each mode and relevant key, maps to the corresponding command's function
          this is the object used internally for handling keys (i.e. translating them to commands)
It also internally maintains
      _keyMaps:
          a 2-layer mapping similar to hotkeys.  For each mode and command name, a list of keys.
          Used for rendering the hotkeys table
          besides translating the mode types into each mode, keyMaps differs from hotkeys by handles some quirky behavior,
          such as making the DELETE_CHAR command always act like DELETE in visual/visual_line modes

###

# TODO: merge this into keyDefinitions

MODES = Modes.modes
NORMAL_MODE_TYPE = Modes.NORMAL_MODE_TYPE
INSERT_MODE_TYPE = Modes.INSERT_MODE_TYPE
MODE_TYPES = Modes.types

class KeyBindings extends EventEmitter
  # takes key definitions and keyMappings, and combines them to key bindings
  getBindings = (definitions, keyMap) ->
    bindings = {}
    for name, v of definitions
      if name == 'MOTION'
        keys = ['MOTION']
      else if (name of keyMap)
        keys = keyMap[name]
      else
        continue

      v = _.cloneDeep v
      v.name = name

      if typeof v.definition == 'object'
        [err, sub_bindings] = getBindings v.definition, keyMap
        if err
          return [err, null]
        else
          v.definition= sub_bindings

      for key in keys
        if key of bindings
          return ["Duplicate binding on key #{key}", bindings]
        bindings[key] = v
    return [null, bindings]

  constructor: (@definitions, hotkey_settings) ->
    super
    # a mapping from commands to keys
    @_keyMaps = null
    # a recursive mapping from keys to commands
    @bindings = null

    @hotkey_settings = null
    err = @apply_hotkey_settings hotkey_settings

    if err
      Logger.logger.error "Failed to apply desired hotkeys #{hotkey_settings}"
      Logger.logger.error err
      do @apply_default_hotkey_settings

  # tries to apply new hotkey settings, returning an error if there was one
  # new bindings may result if any of the following happen:
  #   - hotkey settings change
  #   - mode registered/unregistered
  #   - command, motion, or action registered/unregistered
  apply_hotkey_settings: (hotkey_settings = {}) ->
    # merge hotkey settings into default hotkeys (in case default hotkeys has some new things)
    hotkeys = {}
    for mode_type of MODE_TYPES
      hotkeys[mode_type] = _.extend({}, @definitions.defaultHotkeys[mode_type], hotkey_settings[mode_type] or {})

    # for each mode, get key mapping for that particular mode - a mapping from command to set of keys
    keyMaps = {}
    for mode_type, mode_type_obj of MODE_TYPES
      for mode in mode_type_obj.modes
        modeKeyMap = {}
        for command in @definitions.commands_for_mode mode
          modeKeyMap[command] = hotkeys[mode_type][command].slice()

        if Modes.getMode(mode).within_row
          motions = Object.keys @definitions.WITHIN_ROW_MOTIONS
        else
          motions = Object.keys @definitions.ALL_MOTIONS
        for command in motions
          modeKeyMap[command] = hotkeys[mode_type][command].slice()

        keyMaps[mode] = modeKeyMap

    bindings = {}
    for mode_name, mode of MODES
      [err, mode_bindings] = getBindings (@definitions.actions_for_mode mode), keyMaps[mode]
      if err then return "Error getting bindings for #{mode_name}: #{err}"
      bindings[mode] = mode_bindings

    motion_bindings = {}
    for mode_name, mode of MODES
      [err, mode_bindings] = getBindings @definitions.motions, keyMaps[mode]
      if err then return "Error getting motion bindings for #{mode_name}: #{err}"
      motion_bindings[mode] = mode_bindings

    @hotkeys = hotkeys
    @bindings = bindings
    @motion_bindings = motion_bindings
    @_keyMaps = keyMaps

    @hotkey_settings = hotkey_settings
    @emit 'applied_hotkey_settings', hotkey_settings
    return null

  # apply default hotkeys
  apply_default_hotkey_settings: () ->
      err = @apply_hotkey_settings {}
      errors.assert_equals err, null, "Failed to apply default hotkeys"

  reapply_hotkey_settings: () ->
      err = @apply_hotkey_settings @hotkey_settings
      return err

  # TODO getBindings: (mode) -> return @bindings[mode]

module.exports = KeyBindings
