if module?
  global.Modes = require('../modes.coffee')
  global.keyDefinitions= require('../keyDefinitions.coffee')

(() ->
  MODES = Modes.modes

  CMD_MENU_SELECT = keyDefinitions.registerCommand {
    name: 'MENU_SELECT'
    default_hotkeys:
      insert_like: ['enter']
  }
  keyDefinitions.registerAction [MODES.SEARCH], CMD_MENU_SELECT, {
    description: 'Select current menu selection',
  }, () ->
    do @view.menu.select
    @view.setMode MODES.NORMAL

  CMD_MENU_UP = keyDefinitions.registerCommand {
    name: 'MENU_UP'
    default_hotkeys:
      insert_like: ['ctrl+k', 'up', 'tab']
  }
  keyDefinitions.registerAction [MODES.SEARCH], CMD_MENU_UP, {
    description: 'Select previous menu selection',
  }, () ->
    do @view.menu.up

  CMD_MENU_DOWN = keyDefinitions.registerCommand {
    name: 'MENU_DOWN'
    default_hotkeys:
      insert_like: ['ctrl+j', 'down', 'shift+tab']
  }
  keyDefinitions.registerAction [MODES.SEARCH], CMD_MENU_DOWN, {
    description: 'Select next menu selection',
  }, () ->
    do @view.menu.down

)()
