# imports
if module?
  global._ = require('lodash')

  global.utils = require('./utils.coffee')
  global.Modes = require('./modes.coffee')
  global.errors = require('./errors.coffee')
  global.keyDefinitions = require('./keyDefinitions.coffee')
  global.Logger = require('./logger.coffee')

###
Terminology:
      key       - a key corresponds to a keypress, including modifiers/special keys
      command   - a command is a semantic event.  each command has a string name, and a definition (see keyDefinitions)
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

((exports) ->
  MODES = Modes.modes

  NORMAL_MODE_TYPE = Modes.NORMAL_MODE_TYPE
  INSERT_MODE_TYPE = Modes.INSERT_MODE_TYPE
  MODE_TYPES = Modes.types

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

  registerCommand = (metadata) ->
    utils.tv4_validate(metadata, COMMAND_SCHEMA, "command")
    utils.fill_tv4_defaults(metadata, COMMAND_SCHEMA)
    name = metadata.name
    defaultHotkeys[NORMAL_MODE_TYPE][name] =
      (_.cloneDeep metadata.default_hotkeys.all).concat(
       _.cloneDeep metadata.default_hotkeys.normal_like
      )
    defaultHotkeys[INSERT_MODE_TYPE][name] =
      (_.cloneDeep metadata.default_hotkeys.all).concat(
       _.cloneDeep metadata.default_hotkeys.insert_like
      )

  registerCommand {
    name: 'HELP'
    default_hotkeys:
      insert_like: ['ctrl+?']
      normal_like: ['?']
  }

  registerCommand {
    name: 'INSERT'
    default_hotkeys:
      normal_like: ['i']
  }
  registerCommand {
    name: 'INSERT_HOME'
    default_hotkeys:
      normal_like: ['I']
  }
  registerCommand {
    name: 'INSERT_AFTER'
    default_hotkeys:
      normal_like: ['a']
  }
  registerCommand {
    name: 'INSERT_END'
    default_hotkeys:
      normal_like: ['A']
  }
  registerCommand {
    name: 'INSERT_LINE_BELOW'
    default_hotkeys:
      normal_like: ['o']
  }
  registerCommand {
    name: 'INSERT_LINE_ABOVE'
    default_hotkeys:
      normal_like: ['O']
  }

  registerCommand {
    name: 'LEFT'
    default_hotkeys:
      all: ['left']
      normal_like: ['h']
  }
  registerCommand {
    name: 'RIGHT'
    default_hotkeys:
      all: ['right']
      normal_like: ['l']
  }

  registerCommand {
    name: 'UP'
    default_hotkeys:
      all: ['up']
      normal_like: ['k']
  }
  registerCommand {
    name: 'DOWN'
    default_hotkeys:
      all: ['down']
      normal_like: ['j']
  }

  registerCommand {
    name: 'HOME'
    default_hotkeys:
      all: ['home']
      normal_like: ['0', '^']
      insert_like: ['ctrl+a']
  }
  registerCommand {
    name: 'END'
    default_hotkeys:
      all: ['end']
      normal_like : ['$']
      insert_like: ['ctrl+e']
  }

  registerCommand {
    name: 'BEGINNING_WORD'
    default_hotkeys:
      normal_like: ['b']
      insert_like: ['alt+b']
  }
  registerCommand {
    name: 'END_WORD'
    default_hotkeys:
      normal_like: ['e']
      insert_like: ['alt+f']
  }
  registerCommand {
    name: 'NEXT_WORD'
    default_hotkeys:
      normal_like: ['w']
  }
  registerCommand {
    name: 'BEGINNING_WWORD'
    default_hotkeys:
      normal_like: ['B']
  }
  registerCommand {
    name: 'END_WWORD'
    default_hotkeys:
      normal_like: ['E']
  }
  registerCommand {
    name: 'NEXT_WWORD'
    default_hotkeys:
      normal_like: ['W']
  }
  registerCommand {
    name: 'FIND_NEXT_CHAR'
    default_hotkeys:
      normal_like: ['f']
  }
  registerCommand {
    name: 'FIND_PREV_CHAR'
    default_hotkeys:
      normal_like: ['F']
  }
  registerCommand {
    name: 'TO_NEXT_CHAR'
    default_hotkeys:
      normal_like: ['t']
  }
  registerCommand {
    name: 'TO_PREV_CHAR'
    default_hotkeys:
      normal_like: ['T']
  }

  registerCommand {
    name: 'GO'
    default_hotkeys:
      normal_like: ['g']
  }
  registerCommand {
    name: 'PARENT'
    default_hotkeys:
      normal_like: ['p']
  }
  registerCommand {
    name: 'GO_END'
    default_hotkeys:
      normal_like: ['G']
  }
  registerCommand {
    name: 'EASY_MOTION'
    default_hotkeys:
      normal_like: ['space']
  }

  registerCommand {
    name: 'DELETE'
    default_hotkeys:
      normal_like: ['d']
  }
  registerCommand {
    name: 'DELETE_TO_END'
    default_hotkeys:
      normal_like: ['D']
      insert_like: ['ctrl+k']
  }
  registerCommand {
    name: 'DELETE_TO_HOME'
    default_hotkeys:
      normal_like: []
      insert_like: ['ctrl+u']
  }
  registerCommand {
    name: 'DELETE_LAST_WORD'
    default_hotkeys:
      normal_like: []
      insert_like: ['ctrl+w']
  }
  registerCommand {
    name: 'CHANGE'
    default_hotkeys:
      normal_like: ['c']
  }
  registerCommand {
    name: 'DELETE_CHAR'
    default_hotkeys:
      normal_like: ['x']
      insert_like: ['shift+backspace']
  }
  registerCommand {
    name: 'DELETE_LAST_CHAR'
    default_hotkeys:
      normal_like: ['X']
      insert_like: ['backspace']
  }
  registerCommand {
    name: 'CHANGE_CHAR'
    default_hotkeys:
      normal_like: ['s']
  }
  registerCommand {
    name: 'REPLACE'
    default_hotkeys:
      normal_like: ['r']
  }
  registerCommand {
    name: 'YANK'
    default_hotkeys:
      normal_like: ['y']
  }
  registerCommand {
    name: 'CLONE'
    default_hotkeys:
      normal_like: ['c']
  }
  registerCommand {
    name: 'PASTE_AFTER'
    default_hotkeys:
      normal_like: ['p']
  }
  registerCommand {
    name: 'PASTE_BEFORE'
    default_hotkeys:
      normal_like: ['P']
      insert_like: ['ctrl+y']
  }
  registerCommand {
    name: 'JOIN_LINE'
    default_hotkeys:
      normal_like: ['J']
  }
  registerCommand {
    name: 'SPLIT_LINE'
    default_hotkeys:
      normal_like: ['K']
      insert_like: ['enter']
  }

  registerCommand {
    name: 'INDENT_RIGHT'
    default_hotkeys:
      normal_like: ['>']
  }
  registerCommand {
    name: 'INDENT_LEFT'
    default_hotkeys:
      normal_like: ['<']
  }
  registerCommand {
    name: 'MOVE_BLOCK_RIGHT'
    default_hotkeys:
      normal_like: ['tab', 'ctrl+l']
      insert_like: ['tab']
  }
  registerCommand {
    name: 'MOVE_BLOCK_LEFT'
    default_hotkeys:
      normal_like: ['shift+tab', 'ctrl+h']
      insert_like: ['shift+tab']
  }
  registerCommand {
    name: 'MOVE_BLOCK_DOWN'
    default_hotkeys:
      normal_like: ['ctrl+j']
  }
  registerCommand {
    name: 'MOVE_BLOCK_UP'
    default_hotkeys:
      normal_like: ['ctrl+k']
  }

  registerCommand {
    name: 'NEXT_SIBLING'
    default_hotkeys:
      normal_like: ['alt+j']
  }
  registerCommand {
    name: 'PREV_SIBLING'
    default_hotkeys:
      normal_like: ['alt+k']
  }

  registerCommand {
    name: 'TOGGLE_FOLD'
    default_hotkeys:
      normal_like: ['z']
      insert_like: ['ctrl+z']
  }
  registerCommand {
    name: 'ZOOM_IN'
    default_hotkeys:
      normal_like: [']', 'alt+l', 'ctrl+right']
      insert_like: ['ctrl+right']
  }
  registerCommand {
    name: 'ZOOM_OUT'
    default_hotkeys:
      normal_like: ['[', 'alt+h', 'ctrl+left']
      insert_like: ['ctrl+left']
  }
  registerCommand {
    name: 'ZOOM_IN_ALL'
    default_hotkeys:
      normal_like: ['enter', '}']
      insert_like: ['ctrl+shift+right']
  }
  registerCommand {
    name: 'ZOOM_OUT_ALL'
    default_hotkeys:
      normal_like: ['shift+enter', '{']
      insert_like: ['ctrl+shift+left']
  }
  registerCommand {
    name: 'SCROLL_DOWN'
    default_hotkeys:
      all: ['page down']
      normal_like: ['ctrl+d']
      insert_like: ['ctrl+down']
  }
  registerCommand {
    name: 'SCROLL_UP'
    default_hotkeys:
      all: ['page up']
      normal_like: ['ctrl+u']
      insert_like: ['ctrl+up']
  }

  registerCommand {
    name: 'SEARCH'
    default_hotkeys:
      normal_like: ['/', 'ctrl+f']
  }
  registerCommand {
    name: 'MARK'
    default_hotkeys:
      normal_like: ['m']
  }
  registerCommand {
    name: 'MARK_SEARCH'
    default_hotkeys:
      normal_like: ['\'', '`']
  }
  registerCommand {
    name: 'JUMP_PREVIOUS'
    default_hotkeys:
      normal_like: ['ctrl+o']
  }
  registerCommand {
    name: 'JUMP_NEXT'
    default_hotkeys:
      normal_like: ['ctrl+i']
  }

  registerCommand {
    name: 'UNDO'
    default_hotkeys:
      normal_like: ['u']
  }
  registerCommand {
    name: 'REDO'
    default_hotkeys:
      normal_like: ['ctrl+r']
  }
  registerCommand {
    name: 'REPLAY'
    default_hotkeys:
      normal_like: ['.']
  }
  registerCommand {
    name: 'RECORD_MACRO'
    default_hotkeys:
      normal_like: ['q']
  }
  registerCommand {
    name: 'PLAY_MACRO'
    default_hotkeys:
      normal_like: ['@']
  }

  registerCommand {
    name: 'BOLD'
    default_hotkeys:
      all: ['ctrl+B']
  }
  registerCommand {
    name: 'ITALIC'
    default_hotkeys:
      all: ['ctrl+I']
  }
  registerCommand {
    name: 'UNDERLINE'
    default_hotkeys:
      all: ['ctrl+U']
  }
  registerCommand {
    name: 'STRIKETHROUGH'
    default_hotkeys:
      all: ['ctrl+enter']
  }

  registerCommand {
    name: 'ENTER_VISUAL'
    default_hotkeys:
      normal_like: ['v']
  }
  registerCommand {
    name: 'ENTER_VISUAL_LINE'
    default_hotkeys:
      normal_like: ['V']
  }

  registerCommand {
    name: 'SWAP_CURSOR'
    default_hotkeys:
      normal_like: ['o', 'O']
  }
  registerCommand {
    name: 'EXIT_MODE'
    default_hotkeys:
      all: ['esc', 'ctrl+c']
  }

  # TODO: SWAP_CASE         : ['~']

  registerCommand {
    name: 'MENU_SELECT'
    default_hotkeys:
      insert_like: ['enter']
  }
  registerCommand {
    name: 'MENU_UP'
    default_hotkeys:
      insert_like: ['ctrl+k', 'up', 'tab']
  }
  registerCommand {
    name: 'MENU_DOWN'
    default_hotkeys:
      insert_like: ['ctrl+j', 'down', 'shift+tab']
  }

  registerCommand {
    name: 'FINISH_MARK'
    default_hotkeys:
      insert_like: ['enter']
  }

  WITHIN_ROW_MOTIONS = [
    'LEFT', 'RIGHT',
    'HOME', 'END',
    'BEGINNING_WORD', 'END_WORD', 'NEXT_WORD',
    'BEGINNING_WWORD', 'END_WWORD', 'NEXT_WWORD',
    'FIND_NEXT_CHAR', 'FIND_PREV_CHAR', 'TO_NEXT_CHAR', 'TO_PREV_CHAR',
  ]

  ALL_MOTIONS = [
    WITHIN_ROW_MOTIONS...,

    'UP', 'DOWN',
    'NEXT_SIBLING', 'PREV_SIBLING',

    'GO', 'GO_END', 'PARENT',
    'EASY_MOTION',
  ]

  # set of possible commands for each mode
  commands = {}

  # WTF: this iteration messes things up
  # for k,v of keyDefinitions.actions
  #   console.log k, v

  get_commands_for_mode = (mode, options={}) ->
    # TODO: make sure the command has default hotkeys for that mode
    mode_commands = []
    for motion in (if options.within_row_motions then WITHIN_ROW_MOTIONS else ALL_MOTIONS)
      mode_commands.push motion
    for k of keyDefinitions.actions[mode]
      if k != 'MOTION'
        mode_commands.push k
    return mode_commands

  commands[MODES.NORMAL] = get_commands_for_mode MODES.NORMAL
  commands[MODES.NORMAL].push('CLONE') # is in a sub-dict
  commands[MODES.VISUAL] = get_commands_for_mode MODES.VISUAL
  commands[MODES.VISUAL_LINE] = get_commands_for_mode MODES.VISUAL_LINE
  commands[MODES.INSERT] = get_commands_for_mode MODES.INSERT
  commands[MODES.SEARCH] = get_commands_for_mode MODES.SEARCH, {within_row_motions: true}
  commands[MODES.MARK] = get_commands_for_mode MODES.MARK, {within_row_motions: true}

  # TODO: make sure that the default hotkeys accurately represents the set of possible commands under that mode_type
  #       the following used to work, and should be replaced
  # for mode_type, mode_type_obj of MODE_TYPES
  #   errors.assert_arrays_equal(
  #     _.keys(defaultHotkeys[mode_type]),
  #     _.union.apply(_, mode_type_obj.modes.map((mode) -> commands[mode]))
  #   )

  class KeyBindings
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

        v = _.clone v
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

    constructor: (@settings, options = {}) ->
      # a mapping from commands to keys
      @_keyMaps = null
      # a recursive mapping from keys to commands
      @bindings = null


      hotkey_settings = @settings.getSetting 'hotkeys'
      err = @apply_hotkey_settings hotkey_settings

      if err
        Logger.logger.error "Failed to apply saved hotkeys #{hotkey_settings}"
        Logger.logger.error err
        do @apply_default_hotkey_settings

      @modebindingsDiv = options.modebindingsDiv

    render_hotkeys: () ->
      if $? # TODO: pass this in as an argument
        $('#hotkey-edit-normal').empty().append(
          $('<div>').addClass('tooltip').text(NORMAL_MODE_TYPE).attr('title', MODE_TYPES[NORMAL_MODE_TYPE].description)
        ).append(
          @buildTable @hotkeys[NORMAL_MODE_TYPE], (_.extend.apply @, (_.cloneDeep keyDefinitions.actions[mode] for mode in MODE_TYPES[NORMAL_MODE_TYPE].modes))
        )

        $('#hotkey-edit-insert').empty().append(
          $('<div>').addClass('tooltip').text(INSERT_MODE_TYPE).attr('title', MODE_TYPES[INSERT_MODE_TYPE].description)
        ).append(
          @buildTable @hotkeys[INSERT_MODE_TYPE], (_.extend.apply @, (_.cloneDeep keyDefinitions.actions[mode] for mode in MODE_TYPES[INSERT_MODE_TYPE].modes))
        )

    # tries to apply new hotkey settings, returning an error if there was one
    apply_hotkey_settings: (hotkey_settings) ->
      # merge hotkey settings into default hotkeys (in case default hotkeys has some new things)
      hotkeys = {}
      for mode_type of MODE_TYPES
        hotkeys[mode_type] = _.extend({}, defaultHotkeys[mode_type], hotkey_settings[mode_type] or {})

      # for each mode, get key mapping for that particular mode - a mapping from command to set of keys
      keyMaps = {}
      for mode_type, mode_type_obj of MODE_TYPES
        for mode in mode_type_obj.modes
          modeKeyMap = {}
          for command in commands[mode]
            modeKeyMap[command] = hotkeys[mode_type][command].slice()
          keyMaps[mode] = modeKeyMap

      bindings = {}
      for mode_name, mode of MODES
        [err, mode_bindings] = getBindings keyDefinitions.actions[mode], keyMaps[mode]
        if err then return "Error getting bindings for #{mode_name}: #{err}"
        bindings[mode] = mode_bindings

      motion_bindings = {}
      for mode_name, mode of MODES
        [err, mode_bindings] = getBindings keyDefinitions.motions, keyMaps[mode]
        if err then return "Error getting motion bindings for #{mode_name}: #{err}"
        motion_bindings[mode] = mode_bindings

      @hotkeys = hotkeys
      @bindings = bindings
      @motion_bindings = motion_bindings
      @_keyMaps = keyMaps

      do @render_hotkeys
      return null

    save_settings: (hotkey_settings) ->
      @settings.setSetting 'hotkeys', hotkey_settings

    # apply default hotkeys
    apply_default_hotkey_settings: () ->
        err = @apply_hotkey_settings {}
        errors.assert_equals err, null, "Failed to apply default hotkeys"
        @save_settings {}

    # build table to visualize hotkeys
    buildTable: (keyMap, actions, helpMenu) ->
      buildTableContents = (bindings, onto, recursed=false) ->
        for k,v of bindings
          if k == 'MOTION'
            if recursed
              keys = ['<MOTION>']
            else
              continue
          else
            keys = keyMap[k]
            if not keys
              continue

          if keys.length == 0 and helpMenu
            continue

          row = $('<tr>')

          # row.append $('<td>').text keys[0]
          row.append $('<td>').text keys.join(' OR ')

          display_cell = $('<td>').css('width', '100%').html v.description
          if typeof v.definition == 'object'
            buildTableContents v.definition, display_cell, true
          row.append display_cell

          onto.append row

      tables = $('<div>')

      for [label, definitions] in [['Actions', actions], ['Motions', keyDefinitions.motions]]
        tables.append($('<h5>').text(label).css('margin', '5px 10px'))
        table = $('<table>').addClass('keybindings-table theme-bg-secondary')
        buildTableContents definitions, table
        tables.append(table)

      return tables

    renderModeTable: (mode) ->
      if not @modebindingsDiv
        return
      if not (@settings.getSetting 'showKeyBindings')
        return

      table = @buildTable @_keyMaps[mode], keyDefinitions.actions[mode], true
      @modebindingsDiv.empty().append(table)

    # TODO getBindings: (mode) -> return @bindings[mode]

  module?.exports = KeyBindings
  window?.KeyBindings = KeyBindings
)()
