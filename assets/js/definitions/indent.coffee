Modes = require '../modes.coffee'
keyDefinitions = require '../keyDefinitions.coffee'

MODES = Modes.modes

visual_line_indent = () ->
  return () ->
    @session.indentBlocks @row_start, @num_rows
    @session.setMode MODES.NORMAL
    do @keyStream.save

visual_line_unindent = () ->
  return () ->
    @session.unindentBlocks @row_start, @num_rows
    @session.setMode MODES.NORMAL
    do @keyStream.save

CMD_INDENT_RIGHT = keyDefinitions.registerCommand {
  name: 'INDENT_RIGHT'
  default_hotkeys:
    normal_like: ['>']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INDENT_RIGHT, {
  description: 'Indent row right',
}, () ->
  do @session.indent
  do @keyStream.save
keyDefinitions.registerAction [MODES.INSERT], CMD_INDENT_RIGHT, {
  description: 'Indent row right',
}, () ->
  do @session.indent
# NOTE: this matches block indent behavior, in visual line
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_INDENT_RIGHT, {
  description: 'Indent row right',
}, (do visual_line_indent)

CMD_INDENT_LEFT = keyDefinitions.registerCommand {
  name: 'INDENT_LEFT'
  default_hotkeys:
    normal_like: ['<']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INDENT_LEFT, {
  description: 'Indent row left',
}, () ->
  do @session.unindent
  do @keyStream.save
keyDefinitions.registerAction [MODES.INSERT], CMD_INDENT_LEFT, {
  description: 'Indent row left',
}, () ->
  do @session.unindent
# NOTE: this matches block indent behavior, in visual line
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_INDENT_LEFT, {
  description: 'Indent row left',
}, (do visual_line_unindent)

CMD_MOVE_BLOCK_RIGHT = keyDefinitions.registerCommand {
  name: 'MOVE_BLOCK_RIGHT'
  default_hotkeys:
    normal_like: ['tab', 'ctrl+l']
    insert_like: ['tab']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_MOVE_BLOCK_RIGHT, {
  description: 'Move block right',
}, () ->
  @session.indentBlocks @session.cursor.path, @repeat
  do @keyStream.save
keyDefinitions.registerAction [MODES.INSERT], CMD_MOVE_BLOCK_RIGHT, {
  description: 'Move block right',
}, () ->
  @session.indentBlocks @session.cursor.path, 1
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_MOVE_BLOCK_RIGHT, {
  description: 'Move block right',
}, (do visual_line_indent)

CMD_MOVE_BLOCK_LEFT = keyDefinitions.registerCommand {
  name: 'MOVE_BLOCK_LEFT'
  default_hotkeys:
    normal_like: ['shift+tab', 'ctrl+h']
    insert_like: ['shift+tab']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_MOVE_BLOCK_LEFT, {
  description: 'Move block left',
}, () ->
  @session.unindentBlocks @session.cursor.path, @repeat
  do @keyStream.save
keyDefinitions.registerAction [MODES.INSERT], CMD_MOVE_BLOCK_LEFT, {
  description: 'Move block left',
}, () ->
  @session.unindentBlocks @session.cursor.path, 1
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_MOVE_BLOCK_LEFT, {
  description: 'Move block left',
}, (do visual_line_unindent)

CMD_MOVE_BLOCK_DOWN = keyDefinitions.registerCommand {
  name: 'MOVE_BLOCK_DOWN'
  default_hotkeys:
    normal_like: ['ctrl+j']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_MOVE_BLOCK_DOWN, {
  description: 'Move block down',
}, () ->
  do @session.swapDown
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_MOVE_BLOCK_UP = keyDefinitions.registerCommand {
  name: 'MOVE_BLOCK_UP'
  default_hotkeys:
    normal_like: ['ctrl+k']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_MOVE_BLOCK_UP, {
  description: 'Move block up',
}, () ->
  do @session.swapUp
  if @mode == MODES.NORMAL
    do @keyStream.save
