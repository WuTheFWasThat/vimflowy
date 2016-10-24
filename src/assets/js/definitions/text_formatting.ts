import * as Modes from '../modes';
import keyDefinitions from '../keyDefinitions';

const MODES = Modes.modes;

const CMD_BOLD = keyDefinitions.registerCommand({
  name: 'BOLD',
  default_hotkeys: {
    all: ['ctrl+B'],
  },
});
const CMD_ITALIC = keyDefinitions.registerCommand({
  name: 'ITALIC',
  default_hotkeys: {
    all: ['ctrl+I'],
  },
});
const CMD_UNDERLINE = keyDefinitions.registerCommand({
  name: 'UNDERLINE',
  default_hotkeys: {
    all: ['ctrl+U'],
  },
});
const CMD_STRIKETHROUGH = keyDefinitions.registerCommand({
  name: 'STRIKETHROUGH',
  default_hotkeys: {
    all: ['ctrl+enter'],
  },
});

const text_format_normal = (property) => {
  return async function() {
    await this.session.toggleRowProperty(property);
    this.keyStream.save();
  };
};

const text_format_insert = (property) => {
  return async function() {
    this.session.cursor.toggleProperty(property);
  };
};

const text_format_visual_line = property =>
  async function() {
    const paths = await this.session.document.getChildRange(
      this.parent, this.row_start_i, this.row_end_i
    );
    const rows = paths.map(path => path.row);
    // TODO: dedup rows to avoid double toggle
    await this.session.toggleRowsProperty(property, rows);
    await this.session.setMode(MODES.NORMAL);
    this.keyStream.save();
  }
;

const text_format_visual = property =>
  async function() {
    await this.session.toggleRowPropertyBetween(property, this.session.cursor, this.session.anchor, {includeEnd: true});
    await this.session.setMode(MODES.NORMAL);
    this.keyStream.save();
  }
;

keyDefinitions.registerAction([MODES.NORMAL], CMD_BOLD, {
  description: 'Bold text',
}, text_format_normal('bold'));
keyDefinitions.registerAction([MODES.INSERT], CMD_BOLD, {
  description: 'Bold text',
}, text_format_insert('bold'));
keyDefinitions.registerAction([MODES.VISUAL], CMD_BOLD, {
  description: 'Bold text',
}, text_format_visual('bold'));
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_BOLD, {
  description: 'Bold text',
}, text_format_visual_line('bold'));
keyDefinitions.registerAction([MODES.NORMAL], CMD_ITALIC, {
  description: 'Italicize text',
}, text_format_normal('italic'));
keyDefinitions.registerAction([MODES.INSERT], CMD_ITALIC, {
  description: 'Italicize text',
}, text_format_insert('italic'));
keyDefinitions.registerAction([MODES.VISUAL], CMD_ITALIC, {
  description: 'Italicize text',
}, text_format_visual('italic'));
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_ITALIC, {
  description: 'Italicize text',
}, text_format_visual_line('italic'));
keyDefinitions.registerAction([MODES.NORMAL], CMD_UNDERLINE, {
  description: 'Underline text',
}, text_format_normal('underline'));
keyDefinitions.registerAction([MODES.INSERT], CMD_UNDERLINE, {
  description: 'Underline text',
}, text_format_insert('underline'));
keyDefinitions.registerAction([MODES.VISUAL], CMD_UNDERLINE, {
  description: 'Underline text',
}, text_format_visual('underline'));
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_UNDERLINE, {
  description: 'Underline text',
}, text_format_visual_line('underline'));
keyDefinitions.registerAction([MODES.NORMAL], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, text_format_normal('strikethrough'));
keyDefinitions.registerAction([MODES.INSERT], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, text_format_insert('strikethrough'));
keyDefinitions.registerAction([MODES.VISUAL], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, text_format_visual('strikethrough'));
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_STRIKETHROUGH, {
  description: 'Strike through text',
}, text_format_visual_line('strikethrough'));
