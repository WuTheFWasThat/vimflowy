# imports
if module?
  global._ = require('lodash')
  global.constants = require('./constants.coffee')
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
  MODES = constants.MODES

  NORMAL_MODE_TYPE = 'Normal-like modes'
  INSERT_MODE_TYPE = 'Insert-like modes'
  MODE_TYPES = {}
  MODE_TYPES[NORMAL_MODE_TYPE] = {
    description: 'Modes in which text is not being inserted, and all keys are configurable as commands.  NORMAL, VISUAL, and VISUAL_LINE modes fall under this category.'
    modes: [MODES.NORMAL, MODES.VISUAL, MODES.VISUAL_LINE]
  }
  MODE_TYPES[INSERT_MODE_TYPE] = {
    description: 'Modes in which most text is inserted, and available hotkeys are restricted to those with modifiers.  INSERT, SEARCH, and MARK modes fall under this category.'
    modes: [MODES.INSERT, MODES.SEARCH, MODES.MARK]
  }

  defaultHotkeys = {}

  # key mappings for normal-like modes (normal, visual, visual-line)
  defaultHotkeys[NORMAL_MODE_TYPE] =
    HELP              : ['?']
    INSERT            : ['i']
    INSERT_HOME       : ['I']
    INSERT_AFTER      : ['a']
    INSERT_END        : ['A']
    INSERT_LINE_BELOW : ['o']
    INSERT_LINE_ABOVE : ['O']

    LEFT              : ['h', 'left']
    RIGHT             : ['l', 'right']
    UP                : ['k', 'up']
    DOWN              : ['j', 'down']
    HOME              : ['0', '^']
    END               : ['$']
    BEGINNING_WORD    : ['b']
    END_WORD          : ['e']
    NEXT_WORD         : ['w']
    BEGINNING_WWORD   : ['B']
    END_WWORD         : ['E']
    NEXT_WWORD        : ['W']
    FIND_NEXT_CHAR    : ['f']
    FIND_PREV_CHAR    : ['F']
    TO_NEXT_CHAR      : ['t']
    TO_PREV_CHAR      : ['T']

    GO                : ['g']
    PARENT            : ['p']
    GO_END            : ['G']
    EASY_MOTION       : ['space']

    DELETE            : ['d']
    DELETE_TO_END     : ['D']
    DELETE_TO_HOME    : []
    DELETE_LAST_WORD  : []
    CHANGE            : ['c']
    DELETE_CHAR       : ['x']
    DELETE_LAST_CHAR  : ['X']
    CHANGE_CHAR       : ['s']
    REPLACE           : ['r']
    YANK              : ['y']
    #CLONE             : ['c']
    PASTE_AFTER       : ['p']
    PASTE_BEFORE      : ['P']
    JOIN_LINE         : ['J']
    SPLIT_LINE        : ['K']

    INDENT_RIGHT      : ['>']
    INDENT_LEFT       : ['<']
    MOVE_BLOCK_RIGHT  : ['tab', 'ctrl+l']
    MOVE_BLOCK_LEFT   : ['shift+tab', 'ctrl+h']
    MOVE_BLOCK_DOWN   : ['ctrl+j']
    MOVE_BLOCK_UP     : ['ctrl+k']

    NEXT_SIBLING      : ['alt+j']
    PREV_SIBLING      : ['alt+k']

    TOGGLE_FOLD       : ['z']
    ZOOM_IN           : [']', 'alt+l', 'ctrl+right']
    ZOOM_OUT          : ['[', 'alt+h', 'ctrl+left']
    ZOOM_IN_ALL       : ['enter', '}']
    ZOOM_OUT_ALL      : ['shift+enter', '{']
    SCROLL_DOWN       : ['ctrl+d', 'page down']
    SCROLL_UP         : ['ctrl+u', 'page up']

    SEARCH            : ['/', 'ctrl+f']
    MARK              : ['m']
    MARK_SEARCH       : ['\'', '`']
    JUMP_PREVIOUS     : ['ctrl+o']
    JUMP_NEXT         : ['ctrl+i']

    UNDO              : ['u']
    REDO              : ['ctrl+r']
    REPLAY            : ['.']
    RECORD_MACRO      : ['q']
    PLAY_MACRO        : ['@']

    BOLD              : ['ctrl+B']
    ITALIC            : ['ctrl+I']
    UNDERLINE         : ['ctrl+U']
    STRIKETHROUGH     : ['ctrl+enter']

    ENTER_VISUAL      : ['v']
    ENTER_VISUAL_LINE : ['V']

    SWAP_CURSOR       : ['o', 'O']
    EXIT_MODE         : ['esc', 'ctrl+c']
    # TODO: SWAP_CASE         : ['~']

  # key mappings for insert-like modes (insert, mark, menu)
  defaultHotkeys[INSERT_MODE_TYPE] =
    LEFT              : ['left']
    RIGHT             : ['right']
    UP                : ['up']
    DOWN              : ['down']
    HOME              : ['ctrl+a', 'home']
    END               : ['ctrl+e', 'end']
    DELETE_TO_HOME    : ['ctrl+u']
    DELETE_TO_END     : ['ctrl+k']
    DELETE_LAST_WORD  : ['ctrl+w']
    PASTE_BEFORE      : ['ctrl+y']
    PASTE_AFTER       : []
    BEGINNING_WORD    : ['alt+b']
    END_WORD          : ['alt+f']
    NEXT_WORD         : []
    BEGINNING_WWORD   : []
    END_WWORD         : []
    NEXT_WWORD        : []
    FIND_NEXT_CHAR    : []
    FIND_PREV_CHAR    : []
    TO_NEXT_CHAR      : []
    TO_PREV_CHAR      : []

    BACKSPACE         : ['backspace']
    DELKEY            : ['shift+backspace']
    SPLIT_LINE        : ['enter']

    INDENT_RIGHT      : []
    INDENT_LEFT       : []
    MOVE_BLOCK_RIGHT  : ['tab']
    MOVE_BLOCK_LEFT   : ['shift+tab']
    MOVE_BLOCK_DOWN   : []
    MOVE_BLOCK_UP     : []

    NEXT_SIBLING      : []
    PREV_SIBLING      : []

    TOGGLE_FOLD       : ['ctrl+z']
    ZOOM_OUT          : ['ctrl+left']
    ZOOM_IN           : ['ctrl+right']
    ZOOM_OUT_ALL      : ['ctrl+shift+left']
    ZOOM_IN_ALL       : ['ctrl+shift+right']
    SCROLL_DOWN       : ['page down', 'ctrl+down']
    SCROLL_UP         : ['page up', 'ctrl+up']

    BOLD              : ['ctrl+B']
    ITALIC            : ['ctrl+I']
    UNDERLINE         : ['ctrl+U']
    STRIKETHROUGH     : ['ctrl+enter']

    MENU_SELECT       : ['enter']
    MENU_UP           : ['ctrl+k', 'up', 'tab']
    MENU_DOWN         : ['ctrl+j', 'down', 'shift+tab']

    EXIT_MODE         : ['esc', 'ctrl+c']

    FINISH_MARK       : ['enter']

  # set of possible commands for each mode
  commands = {}

  commands[MODES.NORMAL] = [
    'HELP',
    'INSERT', 'INSERT_HOME', 'INSERT_AFTER', 'INSERT_END', 'INSERT_LINE_BELOW', 'INSERT_LINE_ABOVE',

    'LEFT', 'RIGHT', 'UP', 'DOWN',
    'HOME', 'END',
    'BEGINNING_WORD', 'END_WORD', 'NEXT_WORD',
    'BEGINNING_WWORD', 'END_WWORD', 'NEXT_WWORD',
    'FIND_NEXT_CHAR', 'FIND_PREV_CHAR', 'TO_NEXT_CHAR', 'TO_PREV_CHAR',

    'GO', 'GO_END', 'PARENT',
    'EASY_MOTION',
    'DELETE', 'DELETE_CHAR',
    'CHANGE', 'CHANGE_CHAR',
    'DELETE_TO_HOME', 'DELETE_TO_END', 'DELETE_LAST_CHAR', 'DELETE_LAST_WORD'
    'REPLACE',
    'YANK', 'PASTE_AFTER', 'PASTE_BEFORE',
    'JOIN_LINE', 'SPLIT_LINE',

    'INDENT_RIGHT', 'INDENT_LEFT',
    'MOVE_BLOCK_LEFT', 'MOVE_BLOCK_RIGHT', 'MOVE_BLOCK_UP', 'MOVE_BLOCK_DOWN',

    'NEXT_SIBLING', 'PREV_SIBLING',

    'TOGGLE_FOLD',
    'ZOOM_IN', 'ZOOM_OUT', 'ZOOM_IN_ALL', 'ZOOM_OUT_ALL',
    'SCROLL_DOWN', 'SCROLL_UP',

    'SEARCH',
    'MARK', 'MARK_SEARCH',
    'JUMP_PREVIOUS', 'JUMP_NEXT',

    'UNDO', 'REDO',
    'REPLAY',
    'RECORD_MACRO', 'PLAY_MACRO',

    'BOLD', 'ITALIC', 'UNDERLINE', 'STRIKETHROUGH',

    'ENTER_VISUAL', 'ENTER_VISUAL_LINE',
  ]

  commands[MODES.VISUAL] = [
    'YANK',
    'DELETE',
    'CHANGE',
    'SWAP_CURSOR',
    # TODO: 'REPLACE',
    'BOLD', 'ITALIC', 'UNDERLINE', 'STRIKETHROUGH',
    'EXIT_MODE',
  ]

  commands[MODES.VISUAL_LINE] = [
    'YANK',
    'DELETE',
    'CHANGE',
    'SWAP_CURSOR',
    'MOVE_BLOCK_RIGHT',
    'MOVE_BLOCK_LEFT',
    'EXIT_MODE',
    # TODO: 'REPLACE',
    'BOLD', 'ITALIC', 'UNDERLINE', 'STRIKETHROUGH',
  ]

  commands[MODES.INSERT] = [
    'LEFT', 'RIGHT', 'UP', 'DOWN',
    'HOME', 'END',
    'DELETE_TO_HOME', 'DELETE_TO_END', 'DELETE_LAST_WORD',
    'PASTE_BEFORE', 'PASTE_AFTER',
    'BEGINNING_WORD', 'END_WORD', 'NEXT_WORD',
    'BEGINNING_WWORD', 'END_WWORD', 'NEXT_WWORD',
    'FIND_NEXT_CHAR', 'FIND_PREV_CHAR', 'TO_NEXT_CHAR', 'TO_PREV_CHAR',

    'BACKSPACE', 'DELKEY',
    'SPLIT_LINE',

    'INDENT_RIGHT', 'INDENT_LEFT',
    'MOVE_BLOCK_RIGHT', 'MOVE_BLOCK_LEFT', 'MOVE_BLOCK_DOWN', 'MOVE_BLOCK_UP',

    'NEXT_SIBLING', 'PREV_SIBLING',

    'TOGGLE_FOLD',
    'ZOOM_OUT', 'ZOOM_IN', 'ZOOM_OUT_ALL', 'ZOOM_IN_ALL',
    'SCROLL_DOWN', 'SCROLL_UP',

    'BOLD', 'ITALIC', 'UNDERLINE', 'STRIKETHROUGH',

    'EXIT_MODE',
  ]

  commands[MODES.SEARCH] = [
    'MENU_UP', 'MENU_DOWN',
    'MENU_SELECT',
    'LEFT', 'RIGHT',
    'HOME', 'END',
    'BEGINNING_WORD', 'END_WORD', 'NEXT_WORD',
    'BEGINNING_WWORD', 'END_WWORD', 'NEXT_WWORD',
    'FIND_NEXT_CHAR', 'FIND_PREV_CHAR', 'TO_NEXT_CHAR', 'TO_PREV_CHAR',
    'BACKSPACE', 'DELKEY',
    'EXIT_MODE',
  ]

  commands[MODES.MARK] = [
    'FINISH_MARK',
    'LEFT', 'RIGHT',
    'HOME', 'END',
    'BACKSPACE', 'DELKEY',
    'EXIT_MODE',
  ]

  # make sure that the default hotkeys accurately represents the set of possible commands under that mode_type
  for mode_type, mode_type_obj of MODE_TYPES
    errors.assert_arrays_equal(
      _.keys(defaultHotkeys[mode_type]),
      _.union.apply(_, mode_type_obj.modes.map((mode) -> commands[mode]))
    )

  class KeyBindings
    # takes keyDefinitions and keyMappings, and combines them to key bindings
    getBindings = (definitions, keyMap) ->
      bindings = {}
      for name, v of definitions
        if name == 'MOTION'
          keys = ['MOTION']
        else if (name of keyMap)
          keys = keyMap[name]
        else
          # this definition does not pertain to this context
          continue

        v = _.clone v
        v.name = name
        if v.bindings
          [err, sub_bindings] = getBindings v.bindings, keyMap
          if err
            return [err, null]
          else
            v.bindings = sub_bindings

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
          @buildTable @hotkeys[NORMAL_MODE_TYPE]
        )

        $('#hotkey-edit-insert').empty().append(
          $('<div>').addClass('tooltip').text(INSERT_MODE_TYPE).attr('title', MODE_TYPES[INSERT_MODE_TYPE].description)
        ).append(
          @buildTable @hotkeys[INSERT_MODE_TYPE]
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
      # special case, delete_char -> delete in visual and visual_line
      [].push.apply keyMaps[MODES.VISUAL].DELETE, keyMaps[MODES.NORMAL].DELETE_CHAR
      [].push.apply keyMaps[MODES.VISUAL_LINE].DELETE, keyMaps[MODES.NORMAL].DELETE_CHAR
      # special case, indent -> move in visual_line
      [].push.apply keyMaps[MODES.VISUAL_LINE].MOVE_BLOCK_RIGHT, keyMaps[MODES.NORMAL].INDENT_RIGHT
      [].push.apply keyMaps[MODES.VISUAL_LINE].MOVE_BLOCK_LEFT, keyMaps[MODES.NORMAL].INDENT_LEFT

      bindings = {}
      for mode_name, mode of MODES
        [err, mode_bindings] = getBindings keyDefinitions, keyMaps[mode]
        if err then return "Error getting bindings for #{mode_name}: #{err}"
        bindings[mode] = mode_bindings

      @hotkeys = hotkeys
      @bindings = bindings
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
    buildTable: (keyMap) ->
      table = $('<table>').addClass('keybindings-table theme-bg-secondary')

      buildTableContents = (bindings, onto) ->
        for k,v of bindings
          if k == 'MOTION'
            keys = ['<MOTION>']
          else
            keys = keyMap[k]
            if not keys
              continue

          if keys.length == 0
            continue

          row = $('<tr>')

          # row.append $('<td>').text keys[0]
          row.append $('<td>').text keys.join(' OR ')

          display_cell = $('<td>').css('width', '100%').html v.display
          if v.bindings
            buildTableContents v.bindings, display_cell
          row.append display_cell

          onto.append row
      buildTableContents keyDefinitions, table
      return table

    renderModeTable: (mode) ->
      if not @modebindingsDiv
        return
      if not (@settings.getSetting 'showKeyBindings')
        return

      table = @buildTable @_keyMaps[mode]
      @modebindingsDiv.empty().append(table)

    # TODO getBindings: (mode) -> return @bindings[mode]

  module?.exports = KeyBindings
  window?.KeyBindings = KeyBindings
)()
