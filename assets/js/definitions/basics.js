/* globals window */

import * as Modes from '../modes';
import * as utils from '../utils';
import keyDefinitions from '../keyDefinitions';

const MODES = Modes.modes;

// TODO: SWAP_CASE         : ['~']

// TODO: THIS IS A HACK...
let CMD_MOTION = {name: 'MOTION'};

keyDefinitions.registerAction([MODES.NORMAL], CMD_MOTION, {
  description: 'Move the cursor',
}, function(motion) {
  for (let j = 0; j < this.repeat; j++) {
    motion(this.session.cursor, {});
  }
  return this.keyStream.forget();
});
keyDefinitions.registerAction([MODES.INSERT], CMD_MOTION, {
  description: 'Move the cursor',
}, function(motion) {
  return motion(this.session.cursor, {pastEnd: true});
});
keyDefinitions.registerAction([MODES.VISUAL], CMD_MOTION, {
  description: 'Move the cursor',
}, function(motion) {
  // this is necessary until we figure out multiline
  let tmp = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    motion(tmp, {pastEnd: true});
  }

  if (!(tmp.path.is(this.session.cursor.path))) { // only allow same-row movement
    return this.session.showMessage('Visual mode currently only works on one line', {text_class: 'error'});
  } else {
    return this.session.cursor.from(tmp);
  }
});
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_MOTION, {
  description: 'Move the cursor',
}, function(motion) {
  for (let j = 0; j < this.repeat; j++) {
    motion(this.session.cursor, {pastEnd: true});
  }
  return null;
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MOTION, {
  description: 'Move the cursor',
}, function(motion) {
  return motion(this.session.menu.session.cursor, {pastEnd: true});
});

let CMD_HELP = keyDefinitions.registerCommand({
  name: 'HELP',
  default_hotkeys: {
    insert_like: ['ctrl+?'],
    normal_like: ['?']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.VISUAL, MODES.VISUAL_LINE, MODES.INSERT, MODES.SEARCH], CMD_HELP, {
  description: 'Show/hide key bindings (edit in settings)',
}, function() {
  this.session.toggleBindingsDiv();
  return this.keyStream.forget(1);
});

// TODO: flesh out settings menu commands (in separate file)
// CMD_SETTINGS = keyDefinitions.registerCommand {
//   name: 'SETTINGS'
//   default_hotkeys:
//     normal_like: [':']
// }
// keyDefinitions.registerAction [MODES.NORMAL], CMD_SETTINGS, {
//   description: 'Open settings menu',
// }, () ->
//   @session.setMode MODES.SETTINGS

let CMD_INSERT = keyDefinitions.registerCommand({
  name: 'INSERT',
  default_hotkeys: {
    normal_like: ['i']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT, {
  description: 'Insert at character',
}, function() {
  return this.session.setMode(MODES.INSERT);
});

let CMD_INSERT_AFTER = keyDefinitions.registerCommand({
  name: 'INSERT_AFTER',
  default_hotkeys: {
    normal_like: ['a']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_AFTER, {
  description: 'Insert after character',
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.cursor.right({pastEnd: true});
});

let CMD_INSERT_HOME = keyDefinitions.registerCommand({
  name: 'INSERT_HOME',
  default_hotkeys: {
    normal_like: ['I']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_HOME, {
  description: 'Insert at beginning of line',
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.cursor.home();
});

let CMD_INSERT_END = keyDefinitions.registerCommand({
  name: 'INSERT_END',
  default_hotkeys: {
    normal_like: ['A']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_END, {
  description: 'Insert after end of line',
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.cursor.end({pastEnd: true});
});

let CMD_INSERT_LINE_BELOW = keyDefinitions.registerCommand({
  name: 'INSERT_LINE_BELOW',
  default_hotkeys: {
    normal_like: ['o']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_LINE_BELOW, {
  description: 'Insert on new line after current line',
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.newLineBelow();
});

let CMD_INSERT_LINE_ABOVE = keyDefinitions.registerCommand({
  name: 'INSERT_LINE_ABOVE',
  default_hotkeys: {
    normal_like: ['O']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_INSERT_LINE_ABOVE, {
  description: 'Insert on new line before current line',
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.newLineAbove();
});

let CMD_GO = keyDefinitions.registerCommand({
  name: 'GO',
  default_hotkeys: {
    normal_like: ['g']
  }
});

// TODO: change this
keyDefinitions.registerMotion(CMD_GO, {
  description: 'Various commands for navigation (operator)',
  multirow: true
}, {});

keyDefinitions.registerMotion([CMD_GO, CMD_GO], {
  description: 'Go to the beginning of visible document',
  multirow: true
}, function() {
  return (cursor, options) => cursor.visibleHome(options);
});

let CMD_PARENT = keyDefinitions.registerCommand({
  name: 'PARENT',
  default_hotkeys: {
    normal_like: ['p']
  }
});

keyDefinitions.registerMotion([CMD_GO, CMD_PARENT], {
  description: 'Go to the parent of current line',
  multirow: true
}, function() {
  return (cursor, options) => cursor.parent(options);
});

let CMD_CLONE = keyDefinitions.registerCommand({
  name: 'CLONE',
  default_hotkeys: {
    normal_like: ['c']
  }
});
keyDefinitions.registerMotion([CMD_GO, CMD_CLONE], {
  description: 'Go to next copy of this clone',
  multirow: true
}, function() {
  return (cursor /*, options */) => {
    if (this.session.mode !== MODES.NORMAL) {
      // doesn't work for visual_line mode due to zoomInto
      return;
    }
    let newPath = this.session.document.nextClone(cursor.path);
    cursor.setPath(newPath);
    if (!this.session.isVisible(newPath)) {
      return this.session.zoomInto(newPath);
    }
  };
});

let CMD_LINK = keyDefinitions.registerCommand({
  name: 'LINK',
  default_hotkeys: {
    normal_like: ['x']
  }
});
// TODO: this isn't actually a motion, but that's okay for now...
keyDefinitions.registerMotion([CMD_GO, CMD_LINK], {
  description: 'Visit to the link indicated by the cursor, in a new tab',
}, function() {
  return cursor => {
    let word = this.session.document.getWord(cursor.row, cursor.col);
    if (utils.isLink(word)) {
      return window.open(word);
    }
  };
});

//###################
// ACTIONS
//###################

let visual_line_mode_delete_fn = () =>
  function() {
    this.session.delBlocks(this.parent.row, this.row_start_i, this.num_rows, {addNew: false});
    this.session.setMode(MODES.NORMAL);
    return this.keyStream.save();
  }
;

let visual_mode_delete_fn = () =>
  function() {
    let options = {includeEnd: true, yank: true};
    this.session.deleteBetween(this.session.cursor, this.session.anchor, options);
    this.session.setMode(MODES.NORMAL);
    return this.keyStream.save();
  }
;

let CMD_TOGGLE_FOLD = keyDefinitions.registerCommand({
  name: 'TOGGLE_FOLD',
  default_hotkeys: {
    normal_like: ['z'],
    insert_like: ['ctrl+z']
  }
});

keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_TOGGLE_FOLD, {
  description: 'Toggle whether a block is folded',
}, function() {
  this.session.toggleCurBlockCollapsed();
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

let CMD_REPLACE = keyDefinitions.registerCommand({
  name: 'REPLACE',
  default_hotkeys: {
    normal_like: ['r']
  }
});
// TODO: visual and visual_line mode
keyDefinitions.registerAction([MODES.NORMAL], CMD_REPLACE, {
  description: 'Replace character',
}, function() {
  let key = this.keyStream.dequeue();
  if (key === null) { return this.keyStream.wait(); }
  // TODO: refactor keys so this is unnecessary
  if (key === 'space') { key = ' '; }
  this.session.replaceCharsAfterCursor(key, this.repeat);
  return this.keyStream.save();
});

let CMD_DELETE = keyDefinitions.registerCommand({
  name: 'DELETE',
  default_hotkeys: {
    normal_like: ['d']
  }
});
keyDefinitions.registerAction([MODES.VISUAL], CMD_DELETE, {
  description: 'Delete',
}, (visual_mode_delete_fn()));
keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_DELETE, {
  description: 'Delete',
}, (visual_line_mode_delete_fn()));

keyDefinitions.registerAction([MODES.NORMAL], CMD_DELETE, {
  description: 'Delete (operator)',
}, {});
keyDefinitions.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_DELETE], {
  description: 'Delete blocks'
}, function() {
  this.session.delBlocksAtCursor(this.repeat, {addNew: false});
  return this.keyStream.save();
});
keyDefinitions.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_MOTION], {
  description: 'Delete from cursor with motion'
}, function(motion) {
  let cursor = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    motion(cursor, {pastEnd: true, pastEndWord: true});
  }

  this.session.deleteBetween(this.session.cursor, cursor, { yank: true });
  return this.keyStream.save();
});

let CMD_RECURSIVE = keyDefinitions.registerCommand({
  name: 'RECURSIVE',
  default_hotkeys: {
    normal_like: ['r']
  }
});

//################
// change
//################

let CMD_CHANGE = keyDefinitions.registerCommand({
  name: 'CHANGE',
  default_hotkeys: {
    normal_like: ['c']
  }
});

keyDefinitions.registerAction([MODES.VISUAL], CMD_CHANGE, {
  description: 'Change',
}, function() {
  let options = {includeEnd: true, yank: true};
  this.session.deleteBetween(this.session.cursor, this.session.anchor, options);
  return this.session.setMode(MODES.INSERT);
});

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_CHANGE, {
  description: 'Change',
}, function() {
  this.session.delBlocks(this.parent.row, this.row_start_i, this.num_rows, {addNew: true});
  return this.session.setMode(MODES.INSERT);
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_CHANGE, {
  description: 'Change (operator)',
}, {});

// TODO: support repeat?
keyDefinitions.registerAction([MODES.NORMAL], [CMD_CHANGE, CMD_CHANGE], {
  description: 'Delete row, and enter insert mode'
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.clearRowAtCursor({yank: true});
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_CHANGE, CMD_RECURSIVE], {
  description: 'Delete blocks, and enter insert mode'
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.delBlocksAtCursor(this.repeat, {addNew: true});
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_CHANGE, CMD_MOTION], {
  description: 'Delete from cursor with motion, and enter insert mode'
}, function(motion) {
  let cursor = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    motion(cursor, {pastEnd: true, pastEndWord: true});
  }
  this.session.setMode(MODES.INSERT);
  return this.session.deleteBetween(this.session.cursor, cursor, {yank: true});
});

//################
// yank
//################

let CMD_YANK = keyDefinitions.registerCommand({
  name: 'YANK',
  default_hotkeys: {
    normal_like: ['y']
  }
});

keyDefinitions.registerAction([MODES.VISUAL], CMD_YANK, {
  description: 'Yank',
}, function() {
  let options = {includeEnd: true};
  this.session.yankBetween(this.session.cursor, this.session.anchor, options);
  this.session.setMode(MODES.NORMAL);
  return this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_YANK, {
  description: 'Yank',
}, function() {
  this.session.yankBlocks(this.row_start, this.num_rows);
  this.session.setMode(MODES.NORMAL);
  return this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_YANK, {
  description: 'Yank (operator)',
}, {});

// TODO: support repeat?
keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_YANK], {
  description: 'Yank row'
}, function() {
  this.session.yankRowAtCursor();
  return this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_RECURSIVE], {
  description: 'Yank blocks'
}, function() {
  this.session.yankBlocksAtCursor(this.repeat);
  return this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_MOTION], {
  description: 'Yank from cursor with motion'
}, function(motion) {
  let cursor = this.session.cursor.clone();
  for (let j = 0; j < this.repeat; j++) {
    motion(cursor, {pastEnd: true, pastEndWord: true});
  }

  this.session.yankBetween(this.session.cursor, cursor, {});
  return this.keyStream.forget();
});

keyDefinitions.registerAction([MODES.NORMAL], [CMD_YANK, CMD_CLONE], {
  description: 'Yank blocks as a clone'
}, function() {
  this.session.yankBlocksCloneAtCursor(this.repeat);
  return this.keyStream.forget();
});

//   jeff: c conflicts with change, so this doesn't work
// keyDefinitions.registerAction [MODES.VISUAL_LINE],  CMD_CLONE, {
//   description: 'Yank blocks as a clone',
// }, () ->
//   @session.yankBlocksClone @row_start, @num_rows
//   @session.setMode MODES.NORMAL
//   do @keyStream.forget

//################
// delete
//################

let CMD_DELETE_CHAR = keyDefinitions.registerCommand({
  name: 'DELETE_CHAR',
  default_hotkeys: {
    normal_like: ['x'],
    insert_like: ['delete']
  }
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, function() {
  this.session.delCharsAfterCursor(this.repeat, {yank: true});
  return this.keyStream.save();
});

keyDefinitions.registerAction([MODES.VISUAL], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, (visual_mode_delete_fn()));

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, (visual_line_mode_delete_fn()));

keyDefinitions.registerAction([MODES.INSERT], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, function() {
  return this.session.delCharsAfterCursor(1);
});

keyDefinitions.registerAction([MODES.SEARCH], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, function() {
  return this.session.menu.session.delCharsAfterCursor(1);
});

let CMD_DELETE_LAST_CHAR = keyDefinitions.registerCommand({
  name: 'DELETE_LAST_CHAR',
  default_hotkeys: {
    normal_like: ['X'],
    insert_like: ['backspace', 'shift+backspace']
  }
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, function() {
  let num = Math.min(this.session.cursor.col, this.repeat);
  if (num > 0) {
    this.session.delCharsBeforeCursor(num, {yank: true});
  }
  return this.keyStream.save();
});
// behaves like row delete, in visual line

keyDefinitions.registerAction([MODES.VISUAL], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, (visual_mode_delete_fn()));

keyDefinitions.registerAction([MODES.VISUAL_LINE], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, (visual_line_mode_delete_fn()));

keyDefinitions.registerAction([MODES.INSERT], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, function() {
  return this.session.deleteAtCursor();
});

keyDefinitions.registerAction([MODES.SEARCH], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, function() {
  return this.session.menu.session.deleteAtCursor();
});

let CMD_CHANGE_CHAR = keyDefinitions.registerCommand({
  name: 'CHANGE_CHAR',
  default_hotkeys: {
    normal_like: ['s']
  }
});

keyDefinitions.registerAction([MODES.NORMAL], CMD_CHANGE_CHAR, {
  description: 'Change character',
}, function() {
  this.session.setMode(MODES.INSERT);
  return this.session.delCharsAfterCursor(1, {yank: true});
});

let CMD_DELETE_TO_HOME = keyDefinitions.registerCommand({
  name: 'DELETE_TO_HOME',
  default_hotkeys: {
    normal_like: [],
    insert_like: ['ctrl+u']
  }
});
// TODO: something like this would be nice...
// keyDefinitions.registerActionAsMacro CMD_DELETE_TO_HOME, [CMD_DELETE, CMD_HOME]
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_DELETE_TO_HOME, {
  description: 'Delete to the beginning of the line',
}, function() {
  let options = {
    cursor: {},
    yank: true
  };
  if (this.mode === MODES.INSERT) {
    options.cursor.pastEnd = true;
  }
  this.session.deleteBetween(this.session.cursor, this.session.cursor.clone().home(options.cursor), options);
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

let CMD_DELETE_TO_END = keyDefinitions.registerCommand({
  name: 'DELETE_TO_END',
  default_hotkeys: {
    normal_like: ['D'],
    insert_like: ['ctrl+k']
  }
});
// keyDefinitions.registerActionAsMacro CMD_DELETE_TO_END, [CMD_DELETE, CMD_END]
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_DELETE_TO_END, {
  description: 'Delete to the end of the line',
}, function() {
  let options = {
    yank: true,
    cursor: {},
    includeEnd: true
  };
  if (this.mode === MODES.INSERT) {
    options.cursor.pastEnd = true;
  }
  this.session.deleteBetween(this.session.cursor, this.session.cursor.clone().end(options.cursor), options);
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

let CMD_DELETE_LAST_WORD = keyDefinitions.registerCommand({
  name: 'DELETE_LAST_WORD',
  default_hotkeys: {
    normal_like: [],
    insert_like: ['ctrl+w']
  }
});
// keyDefinitions.registerActionAsMacro CMD_DELETE_LAST_WORD, [CMD_DELETE, CMD_BEGINNING_WWORD]
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_DELETE_LAST_WORD, {
  description: 'Delete to the beginning of the previous word',
}, function() {
  let options = {
    yank: true,
    cursor: {},
    includeEnd: true
  };
  if (this.mode === MODES.INSERT) {
    options.cursor.pastEnd = true;
  }
  this.session.deleteBetween(
    this.session.cursor,
    this.session.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}),
    options
  );
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

let CMD_PASTE_AFTER = keyDefinitions.registerCommand({
  name: 'PASTE_AFTER',
  default_hotkeys: {
    normal_like: ['p']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_PASTE_AFTER, {
  description: 'Paste after cursor',
}, function() {
  this.session.pasteAfter();
  return this.keyStream.save();
});
// NOTE: paste after doesn't make sense for insert mode

let CMD_PASTE_BEFORE = keyDefinitions.registerCommand({
  name: 'PASTE_BEFORE',
  default_hotkeys: {
    normal_like: ['P'],
    insert_like: ['ctrl+y']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_PASTE_BEFORE, {
  description: 'Paste before cursor',
}, function() {
  this.session.pasteBefore();
  return this.keyStream.save();
});
keyDefinitions.registerAction([MODES.INSERT], CMD_PASTE_BEFORE, {
  description: 'Paste before cursor',
}, function() {
  return this.session.pasteBefore();
});

let CMD_JOIN_LINE = keyDefinitions.registerCommand({
  name: 'JOIN_LINE',
  default_hotkeys: {
    normal_like: ['J']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_JOIN_LINE, {
  description: 'Join current line with line below',
}, function() {
  this.session.joinAtCursor();
  return this.keyStream.save();
});

let CMD_SPLIT_LINE = keyDefinitions.registerCommand({
  name: 'SPLIT_LINE',
  default_hotkeys: {
    normal_like: ['K'],
    insert_like: ['enter']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_SPLIT_LINE, {
  description: 'Split line at cursor (i.e. enter key)',
}, function() {
  this.session.newLineAtCursor();
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

let CMD_SCROLL_DOWN = keyDefinitions.registerCommand({
  name: 'SCROLL_DOWN',
  default_hotkeys: {
    all: ['page down'],
    normal_like: ['ctrl+d'],
    insert_like: ['ctrl+down']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_SCROLL_DOWN, {
  description: 'Scroll half window down',
}, function() {
  this.session.scroll(0.5);
  return this.keyStream.forget(1);
});

let CMD_SCROLL_UP = keyDefinitions.registerCommand({
  name: 'SCROLL_UP',
  default_hotkeys: {
    all: ['page up'],
    normal_like: ['ctrl+u'],
    insert_like: ['ctrl+up']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_SCROLL_UP, {
  description: 'Scroll half window up',
}, function() {
  this.session.scroll(-0.5);
  return this.keyStream.forget(1);
});

// for everything but normal mode
let CMD_EXIT_MODE = keyDefinitions.registerCommand({
  name: 'EXIT_MODE',
  default_hotkeys: {
    all: ['esc', 'ctrl+c']
  }
});
keyDefinitions.registerAction([MODES.VISUAL, MODES.VISUAL_LINE, MODES.SEARCH, MODES.SETTINGS], CMD_EXIT_MODE, {
  description: 'Exit back to normal mode',
}, function() {
  this.session.setMode(MODES.NORMAL);
  return this.keyStream.forget();
});
keyDefinitions.registerAction([MODES.INSERT], CMD_EXIT_MODE, {
  description: 'Exit back to normal mode',
}, function() {
  this.session.cursor.left();
  this.session.setMode(MODES.NORMAL);
  // unlike other modes, esc in insert mode keeps changes
  return this.keyStream.save();
});

// for visual and visual line mode
let CMD_ENTER_VISUAL = keyDefinitions.registerCommand({
  name: 'ENTER_VISUAL',
  default_hotkeys: {
    normal_like: ['v']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_ENTER_VISUAL, {
  description: 'Enter visual mode',
}, function() {
  return this.session.setMode(MODES.VISUAL);
});

let CMD_ENTER_VISUAL_LINE = keyDefinitions.registerCommand({
  name: 'ENTER_VISUAL_LINE',
  default_hotkeys: {
    normal_like: ['V']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_ENTER_VISUAL_LINE, {
  description: 'Enter visual line mode',
}, function() {
  return this.session.setMode(MODES.VISUAL_LINE);
});

let CMD_SWAP_CURSOR = keyDefinitions.registerCommand({
  name: 'SWAP_CURSOR',
  default_hotkeys: {
    normal_like: ['o', 'O']
  }
});
keyDefinitions.registerAction([MODES.VISUAL, MODES.VISUAL_LINE], CMD_SWAP_CURSOR, {
  description: 'Swap cursor to other end of selection, in visual and visual line mode',
}, function() {
  let tmp = this.session.anchor.clone();
  this.session.anchor.from(this.session.cursor);
  this.session.cursor.from(tmp);
  return this.keyStream.save();
});

export { CMD_MOTION };
export { CMD_DELETE_LAST_CHAR };
export { CMD_DELETE_CHAR };
export { CMD_HELP };
export { CMD_EXIT_MODE };
