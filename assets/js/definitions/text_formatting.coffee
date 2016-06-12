Modes = require '../modes.coffee'
keyDefinitions = require '../keyDefinitions.coffee'

MODES = Modes.modes

CMD_BOLD = keyDefinitions.registerCommand {
  name: 'BOLD'
  default_hotkeys:
    all: ['ctrl+B']
}
CMD_ITALIC = keyDefinitions.registerCommand {
  name: 'ITALIC'
  default_hotkeys:
    all: ['ctrl+I']
}
CMD_UNDERLINE = keyDefinitions.registerCommand {
  name: 'UNDERLINE'
  default_hotkeys:
    all: ['ctrl+U']
}
CMD_STRIKETHROUGH = keyDefinitions.registerCommand {
  name: 'STRIKETHROUGH'
  default_hotkeys:
    all: ['ctrl+enter']
}

text_format_normal = (property) ->
  return () ->
    ndeleted = @session.toggleRowProperty property
    @session.cursor.setCol (@session.cursor.col + ndeleted - 1)
    do @keyStream.save

text_format_insert = (property) ->
  return () ->
    @session.cursor.toggleProperty property

text_format_visual_line = (property) ->
  return () ->
    paths = @session.document.getChildRange @parent, @row_start_i, @row_end_i
    rows = paths.map((path) -> path.row)
    # TODO: dedup rows to avoid double toggle
    @session.toggleRowsProperty property, rows
    @session.setMode MODES.NORMAL
    do @keyStream.save

text_format_visual = (property) ->
  return () ->
    @session.toggleRowPropertyBetween property, @session.cursor, @session.anchor, {includeEnd: true}
    @session.setMode MODES.NORMAL
    do @keyStream.save

keyDefinitions.registerAction [MODES.NORMAL], CMD_BOLD, {
  description: 'Bold text',
}, (text_format_normal 'bold')
keyDefinitions.registerAction [MODES.INSERT], CMD_BOLD, {
  description: 'Bold text',
}, (text_format_insert 'bold')
keyDefinitions.registerAction [MODES.VISUAL], CMD_BOLD, {
  description: 'Bold text',
}, (text_format_visual 'bold')
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_BOLD, {
  description: 'Bold text',
}, (text_format_visual_line 'bold')
keyDefinitions.registerAction [MODES.NORMAL], CMD_ITALIC, {
  description: 'Italicize text',
}, (text_format_normal 'italic')
keyDefinitions.registerAction [MODES.INSERT], CMD_ITALIC, {
  description: 'Italicize text',
}, (text_format_insert 'italic')
keyDefinitions.registerAction [MODES.VISUAL], CMD_ITALIC, {
  description: 'Italicize text',
}, (text_format_visual 'italic')
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_ITALIC, {
  description: 'Italicize text',
}, (text_format_visual_line 'italic')
keyDefinitions.registerAction [MODES.NORMAL], CMD_UNDERLINE, {
  description: 'Underline text',
}, (text_format_normal 'underline')
keyDefinitions.registerAction [MODES.INSERT], CMD_UNDERLINE, {
  description: 'Underline text',
}, (text_format_insert 'underline')
keyDefinitions.registerAction [MODES.VISUAL], CMD_UNDERLINE, {
  description: 'Underline text',
}, (text_format_visual 'underline')
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_UNDERLINE, {
  description: 'Underline text',
}, (text_format_visual_line 'underline')
keyDefinitions.registerAction [MODES.NORMAL], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, (text_format_normal 'strikethrough')
keyDefinitions.registerAction [MODES.INSERT], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, (text_format_insert 'strikethrough')
keyDefinitions.registerAction [MODES.VISUAL], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, (text_format_visual 'strikethrough')
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, (text_format_visual_line 'strikethrough')
