Modes = require '../modes.coffee'
keyDefinitions = require '../keyDefinitions.coffee'

MODES = Modes.modes

CMD_ZOOM_IN = keyDefinitions.registerCommand {
  name: 'ZOOM_IN'
  default_hotkeys:
    normal_like: [']', 'alt+l', 'ctrl+right']
    insert_like: ['ctrl+right']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_ZOOM_IN, {
  description: 'Zoom in by one level',
}, () ->
  do @session.rootDown
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_ZOOM_OUT = keyDefinitions.registerCommand {
  name: 'ZOOM_OUT'
  default_hotkeys:
    normal_like: ['[', 'alt+h', 'ctrl+left']
    insert_like: ['ctrl+left']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_ZOOM_OUT, {
  description: 'Zoom out by one level',
}, () ->
  do @session.rootUp
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_ZOOM_IN_ALL = keyDefinitions.registerCommand {
  name: 'ZOOM_IN_ALL'
  default_hotkeys:
    normal_like: ['enter', '}']
    insert_like: ['ctrl+shift+right']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_ZOOM_IN_ALL, {
  description: 'Zoom in onto cursor',
}, () ->
  do @session.rootInto
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_ZOOM_OUT_ALL = keyDefinitions.registerCommand {
  name: 'ZOOM_OUT_ALL'
  default_hotkeys:
    normal_like: ['shift+enter', '{']
    insert_like: ['ctrl+shift+left']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_ZOOM_OUT_ALL, {
  description: 'Zoom out to home',
}, () ->
  do @session.reroot
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_JUMP_PREVIOUS = keyDefinitions.registerCommand {
  name: 'JUMP_PREVIOUS'
  default_hotkeys:
    normal_like: ['ctrl+o']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_JUMP_PREVIOUS, {
  description: 'Jump to previous location',
}, () ->
  do @session.jumpPrevious
  @keyStream.forget 1

CMD_JUMP_NEXT = keyDefinitions.registerCommand {
  name: 'JUMP_NEXT'
  default_hotkeys:
    normal_like: ['ctrl+i']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_JUMP_NEXT, {
  description: 'Jump to next location',
}, () ->
  do @session.jumpNext
  @keyStream.forget 1
