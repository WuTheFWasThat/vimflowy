/* globals window */

// tslint:disable:align

import * as Modes from '../modes';
import * as utils from '../utils';
import keyDefinitions from '../keyDefinitions';
import { CursorOptions } from '../types';

const MODES = Modes.modes;

// TODO: SWAP_CASE         : ['~']

// TODO: THIS IS A HACK...
const CMD_MOTION = {name: 'MOTION'};

keyDefinitions.registerAction([MODES.NORMAL], CMD_MOTION, {
  description: 'Move the cursor',
}, async function(motion) {
  for (let j = 0; j < this.repeat; j++) {
    await motion(this.session.cursor, {});
  }
  this.keyStream.forget();
});
keyDefinitions.registerAction([MODES.INSERT], CMD_MOTION, {
  description: 'Move the cursor',
}, async function(motion) {
  await motion(this.session.cursor, {pastEnd: true});
});
keyDefinitions.registerAction([MODES.VISUAL], CMD_MOTION, {
  description: 'Move the cursor',
}, async function(motion) {
  // this is necessary until we figure out multiline
  const tmp = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    await motion(tmp, {pastEnd: true});
  }

  if (!tmp.path.is(this.session.cursor.path)) { // only allow same-row movement
    this.session.showMessage('Visual mode currently only works on one line', {text_class: 'error'});
  } else {
    this.session.cursor.from(tmp);
  }
});
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_MOTION, {
  description: 'Move the cursor',
}, async function(motion) {
  for (let j = 0; j < this.repeat; j++) {
    await motion(this.session.cursor, {pastEnd: true});
  }
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MOTION, {
  description: 'Move the cursor',
}, async function(motion) {
  await motion(this.session.menu.session.cursor, {pastEnd: true});
});

const CMD_HELP = keyDefinitions.registerCommand({
  name: 'HELP',
  default_hotkeys: {
    insert_like: ['ctrl+?'],
    normal_like: ['?'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.VISUAL, MODES.VISUAL_LINE, MODES.INSERT, MODES.SEARCH], CMD_HELP, {
  description: 'Show/hide key bindings (edit in settings)',
}, async function() {
  this.session.toggleBindingsDiv();
  this.keyStream.forget(1);
});

// TODO: flesh out settings menu commands (in separate file)
// CMD_SETTINGS = keyDefinitions.registerCommand({
//   name: 'SETTINGS'
//   default_hotkeys: {
//     normal_like: [':']
//   }
// });
// keyDefinitions.registerAction([MODES.NORMAL], CMD_SETTINGS, {
//   description: 'Open settings menu',
// }, async function() {
//   await this.session.setMode(MODES.SETTINGS);
// });

const CMD_INSERT = keyDefinitions.registerCommand({
  name: 'INSERT',
  default_hotkeys: {
    normal_like: ['i'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT, {
  description: 'Insert at character',
}, async function() {
  await this.session.setMode(MODES.INSERT);
});

const CMD_INSERT_AFTER = keyDefinitions.registerCommand({
  name: 'INSERT_AFTER',
  default_hotkeys: {
    normal_like: ['a'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_AFTER, {
  description: 'Insert after character',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  await this.session.cursor.right({pastEnd: true});
});

const CMD_INSERT_HOME = keyDefinitions.registerCommand({
  name: 'INSERT_HOME',
  default_hotkeys: {
    normal_like: ['I'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_HOME, {
  description: 'Insert at beginning of line',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  await this.session.cursor.home();
});

const CMD_INSERT_END = keyDefinitions.registerCommand({
  name: 'INSERT_END',
  default_hotkeys: {
    normal_like: ['A'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_END, {
  description: 'Insert after end of line',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  await this.session.cursor.end({pastEnd: true});
});

const CMD_INSERT_LINE_BELOW = keyDefinitions.registerCommand({
  name: 'INSERT_LINE_BELOW',
  default_hotkeys: {
    normal_like: ['o'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_LINE_BELOW, {
  description: 'Insert on new line after current line',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  return await this.session.newLineBelow();
});

const CMD_INSERT_LINE_ABOVE = keyDefinitions.registerCommand({
  name: 'INSERT_LINE_ABOVE',
  default_hotkeys: {
    normal_like: ['O'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_LINE_ABOVE, {
  description: 'Insert on new line before current line',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  await this.session.newLineAbove();
});

const CMD_GO = keyDefinitions.registerCommand({
  name: 'GO',
  default_hotkeys: {
    normal_like: ['g'],
  },
});

// TODO: change this
keyDefinitions.registerMotion(CMD_GO, {
  description: 'Various commands for navigation (operator)',
  multirow: true,
}, {});

keyDefinitions.registerMotion([CMD_GO, CMD_GO], {
  description: 'Go to the beginning of visible document',
  multirow: true,
}, async function() {
  return async (cursor, options) => await cursor.visibleHome();
});

const CMD_PARENT = keyDefinitions.registerCommand({
  name: 'PARENT',
  default_hotkeys: {
    normal_like: ['p'],
  },
});

keyDefinitions.registerMotion([CMD_GO, CMD_PARENT], {
  description: 'Go to the parent of current line',
  multirow: true,
}, async function() {
  return async (cursor, options) => await cursor.parent(options);
});

const CMD_CLONE = keyDefinitions.registerCommand({
  name: 'CLONE',
  default_hotkeys: {
    normal_like: ['c'],
  },
});
keyDefinitions.registerMotion([CMD_GO, CMD_CLONE], {
  description: 'Go to next copy of this clone',
  multirow: true,
}, async function() {
  return async (cursor /*, options */) => {
    if (this.session.mode !== MODES.NORMAL) {
      // doesn't work for visual_line mode due to zoomInto
      return;
    }
    const newPath = this.session.document.nextClone(cursor.path);
    await cursor.setPath(newPath);
    if (!this.session.isVisible(newPath)) {
      await this.session.zoomInto(newPath);
    }
  };
});

const CMD_LINK = keyDefinitions.registerCommand({
  name: 'LINK',
  default_hotkeys: {
    normal_like: ['x'],
  },
});
// TODO: this isn't actually a motion, but that's okay for now...
keyDefinitions.registerMotion([CMD_GO, CMD_LINK], {
  description: 'Visit to the link indicated by the cursor, in a new tab',
}, async function() {
  return async (cursor) => {
    const word = await this.session.document.getWord(cursor.row, cursor.col);
    if (utils.isLink(word)) {
      window.open(word);
    }
  };
});

// ACTIONS

const visual_line_mode_delete_fn = () =>
  async function() {
    await this.session.delBlocks(this.parent.row, this.row_start_i, this.num_rows, {addNew: false});
    await this.session.setMode(MODES.NORMAL);
    this.keyStream.save();
  }
;

const visual_mode_delete_fn = () =>
  async function() {
    const options = {includeEnd: true, yank: true};
    this.session.deleteBetween(this.session.cursor, this.session.anchor, options);
    await this.session.setMode(MODES.NORMAL);
    this.keyStream.save();
  }
;

const CMD_TOGGLE_FOLD = keyDefinitions.registerCommand({
  name: 'TOGGLE_FOLD',
  default_hotkeys: {
    normal_like: ['z'],
    insert_like: ['ctrl+z'],
  },
});

keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_TOGGLE_FOLD, {
  description: 'Toggle whether a block is folded',
}, async function() {
  this.session.toggleCurBlockCollapsed();
  if (this.mode === MODES.NORMAL) {
    this.keyStream.save();
  }
});

const CMD_REPLACE = keyDefinitions.registerCommand({
  name: 'REPLACE',
  default_hotkeys: {
    normal_like: ['r'],
  },
});
// TODO: visual and visual_line mode
keyDefinitions.registerAction([MODES.NORMAL], CMD_REPLACE, {
  description: 'Replace character',
}, async function() {
  let key = this.keyStream.dequeue();
  if (key === null) { return this.keyStream.wait(); }
  // TODO: refactor keys so this is unnecessary
  if (key === 'space') { key = ' '; }
  this.session.replaceCharsAfterCursor(key, this.repeat);
  this.keyStream.save();
});

const CMD_DELETE = keyDefinitions.registerCommand({
  name: 'DELETE',
  default_hotkeys: {
    normal_like: ['d'],
  },
});
keyDefinitions.registerAction([MODES.VISUAL], CMD_DELETE, {
  description: 'Delete',
}, visual_mode_delete_fn());
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_DELETE, {
  description: 'Delete',
}, visual_line_mode_delete_fn());

keyDefinitions.registerAction([MODES.NORMAL], CMD_DELETE, {
  description: 'Delete (operator)',
}, {});
keyDefinitions.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_DELETE], {
  description: 'Delete blocks',
}, async function() {
  await this.session.delBlocksAtCursor(this.repeat, {addNew: false});
  this.keyStream.save();
});
keyDefinitions.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_MOTION], {
  description: 'Delete from cursor with motion',
}, async function(motion) {
  const cursor = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    await motion(cursor, {pastEnd: true, pastEndWord: true});
  }

  this.session.deleteBetween(this.session.cursor, cursor, { yank: true });
  this.keyStream.save();
});

const CMD_RECURSIVE = keyDefinitions.registerCommand({
  name: 'RECURSIVE',
  default_hotkeys: {
    normal_like: ['r'],
  },
});

// change

const CMD_CHANGE = keyDefinitions.registerCommand({
  name: 'CHANGE',
  default_hotkeys: {
    normal_like: ['c'],
  },
});

keyDefinitions.registerAction([MODES.VISUAL], CMD_CHANGE, {
  description: 'Change',
}, async function() {
  const options = {includeEnd: true, yank: true};
  this.session.deleteBetween(this.session.cursor, this.session.anchor, options);
  await this.session.setMode(MODES.INSERT);
});

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_CHANGE, {
  description: 'Change',
}, async function() {
  await this.session.delBlocks(this.parent.row, this.row_start_i, this.num_rows, {addNew: true});
  await this.session.setMode(MODES.INSERT);
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_CHANGE, {
  description: 'Change (operator)',
}, {});

// TODO: support repeat?
keyDefinitions.registerAction([MODES.NORMAL], [CMD_CHANGE, CMD_CHANGE], {
  description: 'Delete row, and enter insert mode',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  this.session.clearRowAtCursor({yank: true});
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_CHANGE, CMD_RECURSIVE], {
  description: 'Delete blocks, and enter insert mode',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  await this.session.delBlocksAtCursor(this.repeat, {addNew: true});
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_CHANGE, CMD_MOTION], {
  description: 'Delete from cursor with motion, and enter insert mode',
}, async function(motion) {
  const cursor = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    await motion(cursor, {pastEnd: true, pastEndWord: true});
  }
  await this.session.setMode(MODES.INSERT);
  this.session.deleteBetween(this.session.cursor, cursor, {yank: true});
});

// yank

const CMD_YANK = keyDefinitions.registerCommand({
  name: 'YANK',
  default_hotkeys: {
    normal_like: ['y'],
  },
});

keyDefinitions.registerAction([MODES.VISUAL], CMD_YANK, {
  description: 'Yank',
}, async function() {
  const options = {includeEnd: true};
  this.session.yankBetween(this.session.cursor, this.session.anchor, options);
  await this.session.setMode(MODES.NORMAL);
  this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_YANK, {
  description: 'Yank',
}, async function() {
  this.session.yankBlocks(this.row_start, this.num_rows);
  await this.session.setMode(MODES.NORMAL);
  this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_YANK, {
  description: 'Yank (operator)',
}, {});

// TODO: support repeat?
keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_YANK], {
  description: 'Yank row',
}, async function() {
  this.session.yankRowAtCursor();
  this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_RECURSIVE], {
  description: 'Yank blocks',
}, async function() {
  this.session.yankBlocksAtCursor(this.repeat);
  this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_MOTION], {
  description: 'Yank from cursor with motion',
}, async function(motion) {
  const cursor = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    await motion(cursor, {pastEnd: true, pastEndWord: true});
  }

  this.session.yankBetween(this.session.cursor, cursor, {});
  this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_CLONE], {
  description: 'Yank blocks as a clone',
}, async function() {
  this.session.yankBlocksCloneAtCursor(this.repeat);
  this.keyStream.forget();
});

// NOTE: c conflicts with change, so this doesn't work
// keyDefinitions.registerAction([MODES.VISUAL_LINE],  CMD_CLONE, {
//   description: 'Yank blocks as a clone',
// }, function() {
//   this.session.yankBlocksClone(this.row_start, this.num_rows);
//   await this.session.setMode(MODES.NORMAL);
//   this.keyStream.forget();
// });

// delete

const CMD_DELETE_CHAR = keyDefinitions.registerCommand({
  name: 'DELETE_CHAR',
  default_hotkeys: {
    normal_like: ['x'],
    insert_like: ['delete'],
  },
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, async function() {
  this.session.delCharsAfterCursor(this.repeat, {yank: true});
  this.keyStream.save();
});

keyDefinitions.registerAction([MODES.VISUAL], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, visual_mode_delete_fn());

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, visual_line_mode_delete_fn());

keyDefinitions.registerAction([MODES.INSERT], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, async function() {
  this.session.delCharsAfterCursor(1);
});

keyDefinitions.registerAction([MODES.SEARCH], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, async function() {
  this.session.menu.session.delCharsAfterCursor(1);
});

const CMD_DELETE_LAST_CHAR = keyDefinitions.registerCommand({
  name: 'DELETE_LAST_CHAR',
  default_hotkeys: {
    normal_like: ['X'],
    insert_like: ['backspace', 'shift+backspace'],
  },
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, async function() {
  const num = Math.min(this.session.cursor.col, this.repeat);
  if (num > 0) {
    this.session.delCharsBeforeCursor(num, {yank: true});
  }
  this.keyStream.save();
});
// behaves like row delete, in visual line

keyDefinitions.registerAction([MODES.VISUAL], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, visual_mode_delete_fn());

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, visual_line_mode_delete_fn());

keyDefinitions.registerAction([MODES.INSERT], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, async function() {
  await this.session.deleteAtCursor();
});

keyDefinitions.registerAction([MODES.SEARCH], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, async function() {
  await this.session.menu.session.deleteAtCursor();
});

const CMD_CHANGE_CHAR = keyDefinitions.registerCommand({
  name: 'CHANGE_CHAR',
  default_hotkeys: {
    normal_like: ['s'],
  },
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_CHANGE_CHAR, {
  description: 'Change character',
}, async function() {
  await this.session.setMode(MODES.INSERT);
  this.session.delCharsAfterCursor(1, {yank: true});
});

const CMD_DELETE_TO_HOME = keyDefinitions.registerCommand({
  name: 'DELETE_TO_HOME',
  default_hotkeys: {
    normal_like: [],
    insert_like: ['ctrl+u'],
  },
});
// TODO: something like this would be nice...
// keyDefinitions.registerActionAsMacro CMD_DELETE_TO_HOME, [CMD_DELETE, CMD_HOME]
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_DELETE_TO_HOME, {
  description: 'Delete to the beginning of the line',
}, async function() {
  const options: {
    cursor: CursorOptions,
    yank: boolean
  } = {
    cursor: {},
    yank: true,
  };
  if (this.mode === MODES.INSERT) {
    options.cursor.pastEnd = true;
  }
  this.session.deleteBetween(
    this.session.cursor,
    await this.session.cursor.clone().home(options.cursor),
    options
  );
  if (this.mode === MODES.NORMAL) {
    this.keyStream.save();
  }
});

const CMD_DELETE_TO_END = keyDefinitions.registerCommand({
  name: 'DELETE_TO_END',
  default_hotkeys: {
    normal_like: ['D'],
    insert_like: ['ctrl+k'],
  },
});
// keyDefinitions.registerActionAsMacro CMD_DELETE_TO_END, [CMD_DELETE, CMD_END]
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_DELETE_TO_END, {
  description: 'Delete to the end of the line',
}, async function() {
  const options: {
    cursor: CursorOptions,
    yank: boolean,
    includeEnd: boolean,
  } = {
    yank: true,
    cursor: {},
    includeEnd: true,
  };
  if (this.mode === MODES.INSERT) {
    options.cursor.pastEnd = true;
  }
  this.session.deleteBetween(
    this.session.cursor,
    await this.session.cursor.clone().end(options.cursor),
    options
  );
  if (this.mode === MODES.NORMAL) {
    this.keyStream.save();
  }
});

const CMD_DELETE_LAST_WORD = keyDefinitions.registerCommand({
  name: 'DELETE_LAST_WORD',
  default_hotkeys: {
    normal_like: [],
    insert_like: ['ctrl+w'],
  },
});
// keyDefinitions.registerActionAsMacro CMD_DELETE_LAST_WORD, [CMD_DELETE, CMD_BEGINNING_WWORD]
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_DELETE_LAST_WORD, {
  description: 'Delete to the beginning of the previous word',
}, async function() {
  const options: {
    cursor: CursorOptions,
    yank: boolean,
    includeEnd: boolean,
  } = {
    yank: true,
    cursor: {},
    includeEnd: true,
  };
  if (this.mode === MODES.INSERT) {
    options.cursor.pastEnd = true;
  }
  this.session.deleteBetween(
    this.session.cursor,
    await this.session.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}),
    options
  );
  if (this.mode === MODES.NORMAL) {
    this.keyStream.save();
  }
});

const CMD_PASTE_AFTER = keyDefinitions.registerCommand({
  name: 'PASTE_AFTER',
  default_hotkeys: {
    normal_like: ['p'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_PASTE_AFTER, {
  description: 'Paste after cursor',
}, async function() {
  await this.session.pasteAfter();
  this.keyStream.save();
});
// NOTE: paste after doesn't make sense for insert mode

const CMD_PASTE_BEFORE = keyDefinitions.registerCommand({
  name: 'PASTE_BEFORE',
  default_hotkeys: {
    normal_like: ['P'],
    insert_like: ['ctrl+y'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_PASTE_BEFORE, {
  description: 'Paste before cursor',
}, async function() {
  await this.session.pasteBefore();
  this.keyStream.save();
});
keyDefinitions.registerAction([MODES.INSERT], CMD_PASTE_BEFORE, {
  description: 'Paste before cursor',
}, async function() {
  await this.session.pasteBefore();
});

const CMD_JOIN_LINE = keyDefinitions.registerCommand({
  name: 'JOIN_LINE',
  default_hotkeys: {
    normal_like: ['J'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_JOIN_LINE, {
  description: 'Join current line with line below',
}, async function() {
  await this.session.joinAtCursor();
  this.keyStream.save();
});

const CMD_SPLIT_LINE = keyDefinitions.registerCommand({
  name: 'SPLIT_LINE',
  default_hotkeys: {
    normal_like: ['K'],
    insert_like: ['enter'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_SPLIT_LINE, {
  description: 'Split line at cursor (i.e. enter key)',
}, async function() {
  await this.session.newLineAtCursor();
  if (this.mode === MODES.NORMAL) {
    this.keyStream.save();
  }
});

const CMD_SCROLL_DOWN = keyDefinitions.registerCommand({
  name: 'SCROLL_DOWN',
  default_hotkeys: {
    all: ['page down'],
    normal_like: ['ctrl+d'],
    insert_like: ['ctrl+down'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_SCROLL_DOWN, {
  description: 'Scroll half window down',
}, async function() {
  await this.session.scroll(0.5);
  this.keyStream.forget(1);
});

const CMD_SCROLL_UP = keyDefinitions.registerCommand({
  name: 'SCROLL_UP',
  default_hotkeys: {
    all: ['page up'],
    normal_like: ['ctrl+u'],
    insert_like: ['ctrl+up'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_SCROLL_UP, {
  description: 'Scroll half window up',
}, async function() {
  await this.session.scroll(-0.5);
  this.keyStream.forget(1);
});

// for everything but normal mode
const CMD_EXIT_MODE = keyDefinitions.registerCommand({
  name: 'EXIT_MODE',
  default_hotkeys: {
    all: ['esc', 'ctrl+c'],
  },
});
keyDefinitions.registerAction([MODES.VISUAL, MODES.VISUAL_LINE, MODES.SEARCH, MODES.SETTINGS], CMD_EXIT_MODE, {
  description: 'Exit back to normal mode',
}, async function() {
  await this.session.setMode(MODES.NORMAL);
  this.keyStream.forget();
});
keyDefinitions.registerAction([MODES.INSERT], CMD_EXIT_MODE, {
  description: 'Exit back to normal mode',
}, async function() {
  await this.session.cursor.left();
  await this.session.setMode(MODES.NORMAL);
  // unlike other modes, esc in insert mode keeps changes
  this.keyStream.save();
});

// for visual and visual line mode
const CMD_ENTER_VISUAL = keyDefinitions.registerCommand({
  name: 'ENTER_VISUAL',
  default_hotkeys: {
    normal_like: ['v'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_ENTER_VISUAL, {
  description: 'Enter visual mode',
}, async function() {
  await this.session.setMode(MODES.VISUAL);
});

const CMD_ENTER_VISUAL_LINE = keyDefinitions.registerCommand({
  name: 'ENTER_VISUAL_LINE',
  default_hotkeys: {
    normal_like: ['V'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_ENTER_VISUAL_LINE, {
  description: 'Enter visual line mode',
}, async function() {
  await this.session.setMode(MODES.VISUAL_LINE);
});

const CMD_SWAP_CURSOR = keyDefinitions.registerCommand({
  name: 'SWAP_CURSOR',
  default_hotkeys: {
    normal_like: ['o', 'O'],
  },
});
keyDefinitions.registerAction([MODES.VISUAL, MODES.VISUAL_LINE], CMD_SWAP_CURSOR, {
  description: 'Swap cursor to other end of selection, in visual and visual line mode',
}, async function() {
  const tmp = this.session.anchor.clone();
  this.session.anchor.from(this.session.cursor);
  this.session.cursor.from(tmp);
  this.keyStream.save();
});

export { CMD_MOTION };
export { CMD_DELETE_LAST_CHAR };
export { CMD_DELETE_CHAR };
export { CMD_HELP };
export { CMD_EXIT_MODE };
