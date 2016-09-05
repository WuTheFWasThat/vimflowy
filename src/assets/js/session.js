/* globals document, window */
import $ from 'jquery';
import _ from 'lodash';

import * as mutations from './mutations';
import * as utils from './utils';
import * as errors from './errors';
import Cursor from './cursor';
import Register from './register';
import logger from './logger';
import EventEmitter from './eventEmitter';
import Path from './path';

import * as Modes from './modes';
const MODES = Modes.modes;

/*
a Session represents a session with a vimflowy document
It holds a Cursor, a Document object, and a Settings object
It exposes methods for manipulation of the document, and movement of the cursor

Currently, the separation between the Session and Document classes is not very good.  (see document.js)
Ideally, session shouldn't do much more than handle cursors and history
*/

export default class Session extends EventEmitter {
  constructor(doc, options = {}) {
    super();

    this.document = doc;

    this.bindings = options.bindings;
    this.settings = options.settings;
    // session needs to know div for page scrolling, getting visible rows
    this.mainDiv = options.mainDiv;
    this.menuDiv = options.menuDiv;

    this.showMessage = options.showMessage || ((message) => {
      logger.info(`Showing message: ${message}`);
    });

    this.register = new Register(this);

    this.viewRoot = options.viewRoot || Path.root();
    this.cursor = new Cursor(this, options.cursorPath || this.viewRoot, 0);

    this.reset_history();
    this.reset_jump_history();

    // NOTE: this is fire and forget
    // TODO: fix?
    this.setMode(MODES.NORMAL);
    return this;
  }

  exit() {
    return this.emit('exit');
  }

  //################
  // modes related
  //################

  async setMode(newmode) {
    if (newmode === this.mode) {
      return;
    }

    const oldmode = this.mode;
    if (oldmode) {
      await Modes.getMode(oldmode).exit(this, newmode);
    }

    this.mode = newmode;
    await Modes.getMode(this.mode).enter(this, oldmode);

    return this.emit('modeChange', oldmode, newmode);
  }

  toggleBindingsDiv() {
    return this.emit('toggleBindingsDiv');
  }

  //################
  // import/export #
  //################

  parseJson(content) {
    let root;
    try {
      root = JSON.parse(content);
    } catch (error) {
      this.showMessage('The uploaded file is not valid JSON', {text_class: 'error'});
      return false;
    }
    const verify = function(node) {
      if (node.clone) {
        return true;
      }
      if (!node.text && node.text !== '') { return false; }
      if (node.children) {
        for (let i = 0; i < node.children.length; i++) {
          const child = node.children[i];
          if (!verify(child)) { return false; }
        }
      }
      return true;
    };
    if (!verify(root)) {
      this.showMessage('The uploaded file is not in a valid vimflowy format', {text_class: 'error'});
      return false;
    }
    return root;
  }

  parsePlaintext(content) {
    // Step 1: parse into (int, string) pairs of indentation amounts.
    let lines = [];
    const whitespace = /^\s*/;
    const content_lines = content.split('\n');
    for (let i = 0; i < content_lines.length; i++) {
      let line = content_lines[i];
      if (line.match(/^\s*".*"$/)) { // Flag workflowy annotations as special cases
        lines.push({
          indent: line.match(whitespace)[0].length,
          line: line.replace(/^\s*"(.*)"$/, '$1'),
          annotation: true
        });
        continue;
      }
      // TODO: record whether COMPLETE and strikethrough line if so?
      lines.push({
        indent: line.match(whitespace)[0].length,
        line: line.replace(whitespace, '').replace(/^(?:-\s*)?(?:\[COMPLETE\] )?/, '')
      });
    }
    while (lines[lines.length-1].line === '') { // Strip trailing blank line(s)
      lines = lines.splice(0, lines.length-1);
    }

    // Step 2: convert a list of (int, string, annotation?) into a forest format
    const parseAllChildren = function(parentIndentation, lineNumber) {
      const children = [];
      if (lineNumber < lines.length && lines[lineNumber].annotation) {
        // Each node can have an annotation immediately follow it
        children.push({
          text: lines[lineNumber].line});
        lineNumber = lineNumber + 1;
      }
      while (lineNumber < lines.length && lines[lineNumber].indent > parentIndentation) {
        // For [the first line of] each child
        const child =
          {text: lines[lineNumber].line};
        const result = parseAllChildren(lines[lineNumber].indent, lineNumber + 1);
        ({ lineNumber } = result);
        if (result.children !== null) {
          child.children = result.children;
          child.collapsed = result.children.length > 0;
        }
        children.push(child);
      }
      return { children, lineNumber };
    };
    const forest = (parseAllChildren(-1, 0)).children;
    const root = {
      text: '',
      children: forest,
      collapsed: (forest.length > 0)
    };
    return root;
  }

  parseContent(content, mimetype) {
    if (mimetype === 'application/json') {
      return this.parseJson(content);
    } else if (mimetype === 'text/plain' || mimetype === 'Text') {
      return this.parsePlaintext(content);
    } else {
      return null;
    }
  }

  // TODO: make this use replace_empty = true?
  async importContent(content, mimetype) {
    const root = this.parseContent(content, mimetype);
    if (!root) { return false; }
    const { path } = this.cursor;
    if (root.text === '' && root.children) { // Complete export, not one node
      this.addBlocks(path, 0, root.children);
    } else {
      this.addBlocks(path, 0, [root]);
    }
    this.save();
    this.emit('importFinished');
    return true;
  }

  async exportContent(mimetype) {
    const jsonContent = this.document.serialize();
    if (mimetype === 'application/json') {
      delete jsonContent.viewRoot;
      return JSON.stringify(jsonContent, undefined, 2);
    } else if (mimetype === 'text/plain') {
      // Workflowy compatible plaintext export
      //   Ignores 'collapsed' and viewRoot
      const indent = '  ';
      const exportLines = function(node) {
        if (typeof(node) === 'string') {
          return [`- ${node}`];
        }
        const lines = [];
        lines.push(`- ${node.text}`);
        const children = node.children || [];
        children.forEach((child) => {
          if (child.clone) { return; }
          exportLines(child).forEach((line) => {
            lines.push(`${indent}${line}`);
          });
        });
        return lines;
      };
      return (exportLines(jsonContent)).join('\n');
    } else {
      throw new errors.UnexpectedValue('mimetype', mimetype);
    }
  }

  async exportFile(type = 'json') {
    this.showMessage('Exporting...');
    const filename = this.document.name === '' ?
                   `vimflowy.${type}` :
                   `${this.document.name}.${type}` ;
    // Infer mimetype from file extension
    const mimetype = utils.mimetypeLookup(filename);
    const content = await this.exportContent(mimetype);
    utils.download_file(filename, mimetype, content);
    this.showMessage(`Exported to ${filename}!`, {text_class: 'success'});
  }

  //################
  // MUTATIONS
  //################

  reset_history() {
    this.mutations = []; // full mutation history
    this.history = [{
      index: 0
    }];
    this.historyIndex = 0; // index into indices
  }

  save() {
    if (this.historyIndex !== this.history.length - 1) {
      // haven't acted, otherwise would've sliced
      return;
    }
    if (this.history[this.historyIndex].index === this.mutations.length) {
      // haven't acted, otherwise there would be more mutations
      return;
    }

    const state = this.history[this.historyIndex];
    state.after = {
      cursor: this.cursor.clone(),
      viewRoot: this.viewRoot
    };

    this.historyIndex += 1;
    this.history.push({
      index: this.mutations.length
    });
  }

  async _restoreViewState(state) {
    this.cursor.from(state.cursor);
    await this.fixCursorForMode();
    await this.changeView(state.viewRoot);
  }

  async undo() {
    if (this.historyIndex > 0) {
      const oldState = this.history[this.historyIndex];
      this.historyIndex -= 1;
      const newState = this.history[this.historyIndex];

      logger.debug('UNDOING <');
      for (let j = oldState.index - 1; j > newState.index - 1; j--) {
        const mutation = this.mutations[j];
        logger.debug(`  Undoing mutation ${mutation.constructor.name}(${mutation.str()})`);
        const undo_mutations = mutation.rewind(this);
        undo_mutations.forEach((undo_mutation) => {
          logger.debug(`  Undo mutation ${undo_mutation.constructor.name}(${undo_mutation.str()})`);
          undo_mutation.mutate(this);
          undo_mutation.moveCursor(this.cursor);
        });
      }

      logger.debug('> END UNDO');
      await this._restoreViewState(newState.before);
    }
  }

  async redo() {
    if (this.historyIndex < this.history.length - 1) {
      const oldState = this.history[this.historyIndex];
      this.historyIndex += 1;
      const newState = this.history[this.historyIndex];

      logger.debug('REDOING <');
      for (let j = oldState.index; j < newState.index; j++) {
        const mutation = this.mutations[j];
        logger.debug(`  Redoing mutation ${mutation.constructor.name}(${mutation.str()})`);
        if (!mutation.validate(this)) {
          // this should not happen, since the state should be the same as before
          throw new errors.GenericError(`Failed to redo mutation: ${mutation.str()}`);
        }
        mutation.remutate(this);
        mutation.moveCursor(this.cursor);
      }
      logger.debug('> END REDO');
      await this._restoreViewState(oldState.after);
    }
  }

  do(mutation) {
    if (!this.history) {
      // NOTE: we let mutations through since some plugins may apply mutations on load
      // these mutations won't be undoable, which is desired
      logger.warn(`Tried mutation ${mutation} before init!`);
      mutation.mutate(this);
      return true;
    }

    if (this.historyIndex !== this.history.length - 1) {
      this.history = this.history.slice(0, this.historyIndex + 1);
      this.mutations = this.mutations.slice(0, this.history[this.historyIndex].index);
    }

    const state = this.history[this.historyIndex];
    if (this.mutations.length === state.index) {
      state.before = {
        cursor: this.cursor.clone(),
        viewRoot: this.viewRoot
      };
    }

    logger.debug(`Applying mutation ${mutation.constructor.name}(${mutation.str()})`);
    if (!mutation.validate(this)) {
      return false;
    }
    mutation.mutate(this);
    mutation.moveCursor(this.cursor);
    // TODO: do this elsewhere
    // TODO this is fire and forget.  should await this
    this.fixCursorForMode();

    this.mutations.push(mutation);
    return true;
  }

  async fixCursorForMode() {
    if (Modes.getMode(this.mode).metadata.hotkey_type !== Modes.INSERT_MODE_TYPE) {
      await this.cursor.backIfNeeded();
    }
  }

  //#################
  // viewability
  //#################

  // whether contents are currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable(path) {
    return (!this.document.collapsed(path.row)) || path.is(this.viewRoot);
  }

  nextVisible(path) {
    if (this.viewable(path)) {
      const children = this.document.getChildren(path);
      if (children.length > 0) {
        return children[0];
      }
    }
    if (path.is(this.viewRoot)) {
      return null;
    }
    while (true) {
      const nextsib = this.document.getSiblingAfter(path);
      if (nextsib !== null) {
        return nextsib;
      }
      path = path.parent;
      if (path.is(this.viewRoot)) {
        return null;
      }
    }
  }

  // last thing visible nested within id
  lastVisible(path = this.viewRoot) {
    if (!this.viewable(path)) {
      return path;
    }
    const children = this.document.getChildren(path);
    if (children.length > 0) {
      return this.lastVisible(children[children.length - 1]);
    }
    return path;
  }

  prevVisible(path) {
    if (path.is(this.viewRoot)) {
      return null;
    }
    const prevsib = this.document.getSiblingBefore(path);
    if (prevsib !== null) {
      return this.lastVisible(prevsib);
    }
    const { parent } = path;
    if (parent.is(this.viewRoot)) {
      if (parent.is(this.document.root)) {
        return null;
      } else {
        return this.viewRoot;
      }
    }
    return parent;
  }

  // finds oldest ancestor that is visible *besides viewRoot*
  // returns null if there is no visible ancestor (i.e. path is not under viewroot)
  oldestVisibleAncestor(path) {
    let last = path;
    while (true) {
      const cur = last.parent;
      if (cur.is(this.viewRoot)) {
        return last;
      }
      if (cur.isRoot()) {
        return null;
      }
      last = cur;
    }
  }

  // finds closest ancestor that is visible
  // returns null if there is no visible ancestor (i.e. path is not under viewroot)
  youngestVisibleAncestor(path) {
    let answer = path;
    let cur = path;
    while (true) {
      if (cur.is(this.viewRoot)) {
        return answer;
      }
      if (cur.isRoot()) {
        return null;
      }
      if (this.document.collapsed(cur.row)) {
        answer = cur;
      }
      cur = cur.parent;
    }
  }

  isVisible(path) {
    const visibleAncestor = this.youngestVisibleAncestor(path);
    return (visibleAncestor !== null) && path.is(visibleAncestor);
  }

  //#################
  // View root
  //#################

  async changeViewRoot(path) {
    this.viewRoot = path;
    return this.document.store.setLastViewRoot(path.getAncestry());
  }

  reset_jump_history() {
    this.jumpHistory = [{
      viewRoot: this.viewRoot,
      cursor_before: this.cursor.clone()
    }];
    return this.jumpIndex = 0; // index into jump history
  }

  _addToJumpHistory(jump_fn) {
    const jump = this.jumpHistory[this.jumpIndex];
    jump.cursor_after = this.cursor.clone();

    this.jumpHistory = this.jumpHistory.slice(0, this.jumpIndex+1);

    jump_fn();

    this.jumpHistory.push({
      viewRoot: this.viewRoot,
      cursor_before: this.cursor.clone()
    });
    this.jumpIndex += 1;
  }

  // try going to jump, return true if succeeds
  async tryJump(jump) {
    if (jump.viewRoot.row === this.viewRoot.row) {
      return false; // not moving, don't jump
    }

    if (!this.document.isAttached(jump.viewRoot.row)) {
      return false; // invalid location
    }

    const children = this.document.getChildren(jump.viewRoot);

    await this.changeViewRoot(jump.viewRoot);
    if (children.length) {
      await this.cursor.setPath(children[0]);
    } else {
      await this.cursor.setPath(jump.viewRoot);
    }

    if (this.document.isAttached(jump.cursor_after.row)) {
      // if the row is attached and under the view root, switch to it
      const cursor_path = this.youngestVisibleAncestor(jump.cursor_after.path);
      if (cursor_path !== null) {
        await this.cursor.setPath(cursor_path);
      }
    }
    return true;
  }

  async jumpPrevious() {
    let jumpIndex = this.jumpIndex;

    const jump = this.jumpHistory[jumpIndex];
    jump.cursor_after = this.cursor.clone();

    while (true) {
      if (jumpIndex === 0) {
        return false;
      }
      jumpIndex -= 1;
      const oldjump = this.jumpHistory[jumpIndex];
      if (await this.tryJump(oldjump)) {
        this.jumpIndex = jumpIndex;
        return true;
      }
    }
  }

  async jumpNext() {
    let jumpIndex = this.jumpIndex;

    const jump = this.jumpHistory[jumpIndex];
    jump.cursor_after = this.cursor.clone();

    while (true) {
      if (jumpIndex === this.jumpHistory.length - 1) {
        return false;
      }
      jumpIndex += 1;
      const newjump = this.jumpHistory[jumpIndex];
      if (await this.tryJump(newjump)) {
        this.jumpIndex = jumpIndex;
        return true;
      }
    }
  }

  // try to change the view root to row
  // fails if there is no child
  // records in jump history
  async changeView(path) {
    if (path.row === this.viewRoot.row) {
      return; // not moving, do nothing
    }
    await this._addToJumpHistory(async () => {
      return await this.changeViewRoot(path);
    });
  }

  // try to zoom into newroot, updating the cursor
  async zoomInto(newroot) {
    await this.changeView(newroot);
    let newrow = this.youngestVisibleAncestor(this.cursor.path);
    if (newrow === null) { // not visible, need to reset cursor
      newrow = newroot;
    }
    await this.cursor.setPath(newrow);
  }

  async zoomOut() {
    if (this.viewRoot.row !== this.document.root.row) {
      const { parent } = this.viewRoot;
      return await this.zoomInto(parent);
    }
  }

  async zoomIn() {
    if (this.cursor.path.is(this.viewRoot)) {
      return false;
    }
    const newroot = this.oldestVisibleAncestor(this.cursor.path);
    if (await this.zoomInto(newroot)) {
      return true;
    }
    return false;
  }

  async zoomDown() {
    const sib = this.document.getSiblingAfter(this.viewRoot);
    if (sib === null) {
      this.showMessage('No next sibling to zoom down to', {text_class: 'error'});
      return;
    }
    return await this.zoomInto(sib);
  }

  async zoomUp() {
    const sib = this.document.getSiblingBefore(this.viewRoot);
    if (sib === null) {
      this.showMessage('No previous sibling to zoom up to', {text_class: 'error'});
      return;
    }
    return await this.zoomInto(sib);
  }

  //#################
  // Text
  //#################

  curLine() {
    return this.document.getLine(this.cursor.row);
  }

  curText() {
    return this.document.getText(this.cursor.row);
  }

  curLineLength() {
    return this.document.getLength(this.cursor.row);
  }

  addChars(row, col, chars) {
    return this.do(new mutations.AddChars(row, col, chars));
  }

  addCharsAtCursor(chars) {
    return this.addChars(this.cursor.row, this.cursor.col, chars);
  }

  addCharsAfterCursor(chars) {
    let col = this.cursor.col;
    if (col < this.document.getLength(this.cursor.row)) {
      col += 1;
    }
    return this.addChars(this.cursor.row, col, chars);
  }

  delChars(path, col, nchars, options = {}) {
    const n = this.document.getLength(path.row);
    let deleted = [];
    if ((n > 0) && (nchars > 0) && (col < n)) {
      const mutation = new mutations.DelChars(path.row, col, nchars);
      this.do(mutation);
      deleted = mutation.deletedChars;
      if (options.yank) {
        this.register.saveChars(deleted);
      }
    }
    return deleted;
  }

  delCharsBeforeCursor(nchars, options) {
    nchars = Math.min(this.cursor.col, nchars);
    return this.delChars(this.cursor.path, (this.cursor.col-nchars), nchars, options);
  }

  delCharsAfterCursor(nchars, options) {
    return this.delChars(this.cursor.path, this.cursor.col, nchars, options);
  }

  changeChars(row, col, nchars, change_fn) {
    const mutation = new mutations.ChangeChars(row, col, nchars, change_fn);
    this.do(mutation);
    return mutation.ncharsDeleted;
  }

  replaceCharsAfterCursor(char, nchars) {
    const ndeleted = this.changeChars(this.cursor.row, this.cursor.col, nchars, (chars =>
      chars.map(function(char_obj) {
        const new_obj = _.clone(char_obj);
        new_obj.char = char;
        return new_obj;
      })
    ));
    return this.cursor.setCol(this.cursor.col + ndeleted - 1);
  }

  clearRowAtCursor(options) {
    if (options.yank) {
      // yank as a row, not chars
      this.yankRowAtCursor();
    }
    return this.delChars(this.cursor.path, 0, this.curLineLength());
  }

  yankChars(path, col, nchars) {
    const line = this.document.getLine(path.row);
    if (line.length > 0) {
      return this.register.saveChars(line.slice(col, col + nchars));
    }
  }

  // options:
  //   - includeEnd says whether to also delete cursor2 location
  yankBetween(cursor1, cursor2, options = {}) {
    if (!cursor2.path.is(cursor1.path)) {
      logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }

    const offset = options.includeEnd ? 1 : 0;
    return this.yankChars(cursor1.path, cursor1.col, cursor2.col - cursor1.col + offset);
  }

  yankRowAtCursor() {
    const serialized_row = this.document.serializeRow(this.cursor.row);
    return this.register.saveSerializedRows([serialized_row]);
  }

  // options:
  //   - includeEnd says whether to also delete cursor2 location
  deleteBetween(cursor1, cursor2, options = {}) {
    if (!cursor2.path.is(cursor1.path)) {
      logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }
    const offset = options.includeEnd ? 1 : 0;
    return this.delChars(cursor1.path, cursor1.col, cursor2.col - cursor1.col + offset, options);
  }

  // TODO: fix a bunch of these to use rows (they're still actually paths)

  // toggling text properties
  // if new_value is null, should be inferred based on old values
  toggleProperty(property, new_value, row, col, n) {
    return this.changeChars(row, col, n, function(deleted) {
      if (new_value === null) {
        const all_were_true = _.every(deleted.map(obj => obj[property]));
        new_value = !all_were_true;
      }

      return deleted.map(function(char_obj) {
        const new_obj = _.clone(char_obj);
        new_obj[property] = new_value;
        return new_obj;
      });
    });
  }

  toggleRowsProperty(property, rows) {
    const all_were_true = _.every(rows.map(row => {
      return _.every(this.document.getLine(row).map(obj => obj[property]));
    }));
    const new_value = !all_were_true;
    rows.forEach((row) => {
      this.toggleProperty(property, new_value, row, 0, this.document.getLength(row));
    });
    return null;
  }

  toggleRowProperty(property, row = this.cursor.row) {
    return this.toggleProperty(property, null, row, 0, this.document.getLength(row));
  }

  toggleRowPropertyBetween(property, cursor1, cursor2, options) {
    if (!(cursor2.path.is(cursor1.path))) {
      logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }

    const offset = options.includeEnd ? 1 : 0;
    return this.toggleProperty(property, null, cursor1.row, cursor1.col, cursor2.col - cursor1.col + offset);
  }

  async newLineBelow(options = {}) {
    options.setCursor = 'first';

    if (this.cursor.path.is(this.viewRoot)) {
      if (!this.document.hasChildren(this.cursor.row)) {
        if (!this.document.collapsed(this.cursor.row)) {
          this.toggleBlockCollapsed(this.cursor.row);
        }
      }

      return this.addBlocks(this.cursor.path, 0, [''], options);
    } else if ((!this.document.collapsed(this.cursor.row)) && this.document.hasChildren(this.cursor.row)) {
      return this.addBlocks(this.cursor.path, 0, [''], options);
    } else {
      const parent = this.cursor.path.parent;
      const index = this.document.indexOf(this.cursor.path);
      return this.addBlocks(parent, (index+1), [''], options);
    }
  }

  async newLineAbove() {
    if (this.cursor.path.is(this.viewRoot)) {
      return;
    }
    const parent = this.cursor.path.parent;
    const index = this.document.indexOf(this.cursor.path);
    return this.addBlocks(parent, index, [''], {setCursor: 'first'});
  }

  // behavior of "enter", splitting a line
  // If enter is not at the end:
  //     insert a new node before with the first half of the content
  //     note that this will always preserve child-parent relationships
  // If enter is at the end:
  //     insert a new node after
  //     if the node has children, this is the new first child
  async newLineAtCursor() {
    if (this.cursor.col === this.document.getLength(this.cursor.row)) {
      return await this.newLineBelow({cursorOptions: {keepProperties: true}});
    } else {
      const mutation = new mutations.DelChars(this.cursor.row, 0, this.cursor.col);
      this.do(mutation);
      const path = this.cursor.path;

      await this.newLineAbove();
      // cursor now is at inserted path, add the characters
      this.addCharsAfterCursor(mutation.deletedChars);
      // restore cursor
      return this.cursor.setPosition(path, 0, {keepProperties: true});
    }
  }

  // can only join if either:
  // - first is previous sibling of second, AND has no children
  // - second is first child of first, AND has no children
  async _joinRows(first, second, options = {}) {
    let addDelimiter = false;
    const firstLine = this.document.getLine(first.row);
    const secondLine = this.document.getLine(second.row);
    if (options.delimiter) {
      if (firstLine.length && secondLine.length) {
        if (firstLine[firstLine.length - 1].char !== options.delimiter) {
          if (secondLine[0].char !== options.delimiter) {
            addDelimiter = true;
          }
        }
      }
    }

    if (!this.document.hasChildren(second.row)) {
      this.cursor.setPosition(first, -1);
      await this.delBlock(second, {noNew: true, noSave: true});
      if (addDelimiter) {
        const mutation = new mutations.AddChars(first.row, firstLine.length, [{ char: options.delimiter }]);
        this.do(mutation);
      }
      const mutation = new mutations.AddChars(first.row, (firstLine.length + addDelimiter), secondLine);
      this.do(mutation);
      this.cursor.setPosition(first, firstLine.length);
      return true;
    }

    if (this.document.hasChildren(first.row)) {
      this.showMessage('Cannot join when both rows have children', {text_class: 'error'});
      return false;
    }

    if (second.parent.row !== first.parent.row) {
      this.showMessage('Cannot join with non sibling/child', {text_class: 'error'});
      return false;
    }

    this.cursor.setPosition(second, 0);
    await this.delBlock(first, {noNew: true, noSave: true});
    if (addDelimiter) {
      const mutation = new mutations.AddChars(second.row, 0, [{ char: options.delimiter }]);
      this.do(mutation);
    }
    const mutation = new mutations.AddChars(second.row, 0, firstLine);
    this.do(mutation);

    if (addDelimiter) {
      await this.cursor.left();
    }

    return true;
  }

  async joinAtCursor() {
    const path = this.cursor.path;
    const sib = this.nextVisible(path);
    if (sib !== null) {
      return await this._joinRows(path, sib, {delimiter: ' '});
    }
  }

  // implements proper "backspace" behavior
  async deleteAtCursor() {
    if (this.cursor.col > 0) {
      this.delCharsBeforeCursor(1, {cursor: {pastEnd: true}});
      return true;
    }

    const path = this.cursor.path;
    const sib = this.prevVisible(path);
    if (sib === null) {
      return false;
    }

    if (await this._joinRows(sib, path)) {
      return true;
    }

    return false;
  }

  async delBlock(path, options) {
    return await this.delBlocks(path.parent.row, this.document.indexOf(path), 1, options);
  }

  async delBlocks(parent, index, nrows, options = {}) {
    const mutation = new mutations.DetachBlocks(parent, index, nrows, options);
    this.do(mutation);
    if (!options.noSave) {
      this.register.saveClonedRows(mutation.deleted);
    }
    if (!this.isVisible(this.cursor.path)) {
      // view root got deleted
      return await this.zoomOut();
    }
  }

  async delBlocksAtCursor(nrows, options = {}) {
    const parent = this.cursor.path.parent;
    const index = this.document.indexOf(this.cursor.path);
    return await this.delBlocks(parent.row, index, nrows, options);
  }

  addBlocks(parent, index = -1, serialized_rows, options = {}) {
    const mutation = new mutations.AddBlocks(parent, index, serialized_rows, options);
    this.do(mutation);
    if (options.setCursor === 'first') {
      return this.cursor.setPosition(mutation.added_rows[0], 0, options.cursorOptions);
    } else if (options.setCursor === 'last') {
      return this.cursor.setPosition(mutation.added_rows[mutation.added_rows.length - 1], 0, options.cursorOptions);
    }
  }

  yankBlocks(path, nrows) {
    const siblings = this.document.getSiblingRange(path, 0, nrows-1).filter(x => x !== null);
    const serialized = siblings.map(x => this.document.serialize(x.row));
    return this.register.saveSerializedRows(serialized);
  }

  yankBlocksAtCursor(nrows) {
    return this.yankBlocks(this.cursor.path, nrows);
  }

  yankBlocksClone(row, nrows) {
    const siblings = this.document.getSiblingRange(row, 0, nrows-1).filter(x => x !== null);
    return this.register.saveClonedRows(siblings.map(sibling => sibling.row));
  }

  yankBlocksCloneAtCursor(nrows) {
    return this.yankBlocksClone(this.cursor.path, nrows);
  }

  attachBlocks(parent, ids, index = -1, options = {}) {
    const mutation = new mutations.AttachBlocks(parent.row, ids, index, options);
    const will_work = mutation.validate(this);
    this.do(mutation);

    // TODO: do this more elegantly
    if (will_work) {
      if (options.setCursor === 'first') {
        return this.cursor.setPosition(this.document.findChild(parent, ids[0]), 0);
      } else if (this.options.setCursor === 'last') {
        return this.cursor.setPosition(this.document.findChild(parent, ids[ids.length-1]), 0);
      }
    }
  }

  moveBlock(path, parent_path, index = -1) {
    return this.do(new mutations.MoveBlock(path, parent_path, index));
  }

  indentBlocks(row, numblocks = 1) {
    if (row.is(this.viewRoot)) {
      this.showMessage('Cannot indent view root', {text_class: 'error'});
      return;
    }
    const newparent = this.document.getSiblingBefore(row);
    if (newparent === null) {
      this.showMessage('Cannot indent without higher sibling', {text_class: 'error'});
      return null; // cannot indent
    }

    if (this.document.collapsed(newparent.row)) {
      this.toggleBlockCollapsed(newparent.row);
    }

    const siblings = this.document.getSiblingRange(row, 0, numblocks-1).filter(sib => sib !== null);
    siblings.forEach((sib) => {
      this.moveBlock(sib, newparent, -1);
    });
    return newparent;
  }

  unindentBlocks(row, numblocks = 1) {
    if (row.is(this.viewRoot)) {
      this.showMessage('Cannot unindent view root', {text_class: 'error'});
      return;
    }
    const parent = row.parent;
    if (parent.row === this.viewRoot.row) {
      this.showMessage('Cannot unindent past root', {text_class: 'error'});
      return null;
    }

    const siblings = this.document.getSiblingRange(row, 0, numblocks-1).filter(sib => sib !== null);

    const newparent = parent.parent;
    let pp_i = this.document.indexOf(parent);

    siblings.forEach((sib) => {
      pp_i += 1;
      this.moveBlock(sib, newparent, pp_i);
    });
    return newparent;
  }

  indent(path = this.cursor.path) {
    if (path.is(this.viewRoot)) {
      this.showMessage('Cannot indent view root', {text_class: 'error'});
      return;
    }
    if (this.document.collapsed(path.row)) {
      return this.indentBlocks(path);
    }

    const sib = this.document.getSiblingBefore(path);

    const newparent = this.indentBlocks(path);
    if (newparent === null) {
      return;
    }
    this.document.getChildren(path).forEach((child) => {
      this.moveBlock(child, sib, -1);
    });
  }

  unindent(path = this.cursor.path) {
    if (path.is(this.viewRoot)) {
      this.showMessage('Cannot unindent view root', {text_class: 'error'});
      return;
    }
    if (this.document.collapsed(path.row)) {
      return this.unindentBlocks(path);
    }

    if (this.document.hasChildren(path.row)) {
      this.showMessage('Cannot unindent line with children', {text_class: 'error'});
      return;
    }

    const parent = path.parent;
    const p_i = this.document.indexOf(path);

    const newparent = this.unindentBlocks(path);
    if (newparent === null) {
      return;
    }

    const p_children = this.document.getChildren(parent);
    p_children.slice(p_i).forEach((child) => {
      this.moveBlock(child, path, -1);
    });
  }

  swapDown(path = this.cursor.path) {
    const next = this.nextVisible(this.lastVisible(path));
    if (next === null) {
      return;
    }

    if (this.document.hasChildren(next.row) && !this.document.collapsed(next.row)) {
      // make it the first child
      return this.moveBlock(path, next, 0);
    } else {
      // make it the next sibling
      const parent = next.parent;
      const p_i = this.document.indexOf(next);
      return this.moveBlock(path, parent, p_i+1);
    }
  }

  swapUp(path = this.cursor.path) {
    const prev = this.prevVisible(path);
    if (prev === null) {
      return;
    }

    // make it the previous sibling
    const parent = prev.parent;
    const p_i = this.document.indexOf(prev);
    return this.moveBlock(path, parent, p_i);
  }

  toggleCurBlockCollapsed() {
    return this.toggleBlockCollapsed(this.cursor.row);
  }

  toggleBlockCollapsed(row) {
    return this.do(new mutations.ToggleBlock(row));
  }

  async pasteBefore() {
    return await this.register.paste({before: true});
  }

  async pasteAfter() {
    return await this.register.paste({});
  }

  // given an anchor and cursor, figures out the right blocks to be deleting
  // returns a parent, minindex, and maxindex
  getVisualLineSelections() {
    const [common, ancestors1, ancestors2] = this.document.getCommonAncestor(this.cursor.path, this.anchor.path);
    if (ancestors1.length === 0) {
      // anchor is underneath cursor
      const parent = common.parent;
      const index = this.document.indexOf(this.cursor.path);
      return [parent, index, index];
    } else if (ancestors2.length === 0) {
      // cursor is underneath anchor
      const parent = common.parent;
      const index = this.document.indexOf(this.anchor.path);
      return [parent, index, index];
    } else {
      let index1 = this.document.indexOf(ancestors1[0] || this.cursor.path);
      let index2 = this.document.indexOf(ancestors2[0] || this.anchor.path);
      if (index2 < index1) {
        [index1, index2] = [index2, index1];
      }
      return [common, index1, index2];
    }
  }

  //##################
  // scrolling
  //##################

  async scroll(npages) {
    this.emit('scroll', npages);
    // TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
    const line_height = $('.node-text').height() || 21;
    errors.assert(line_height > 0);
    const page_height = $(document).height();
    const height = npages * page_height;

    let numlines = Math.round(height / line_height);
    numlines = Math.max(Math.min(numlines, 1000), -1000); // guard against craziness

    if (numlines > 0) {
      for (let j = 0; j < numlines; j++) {
        await this.cursor.down();
      }
    } else {
      for (let j = 0; j < -numlines; j++) {
        await this.cursor.up();
      }
    }

    return this.scrollMain(line_height * numlines);
  }

  scrollMain(amount) {
    // # animate.  seems to not actually be great though
    // @mainDiv.stop().animate({
    //     scrollTop: @mainDiv[0].scrollTop + amount
    //  }, 50)
    return this.mainDiv.scrollTop(this.mainDiv.scrollTop() + amount);
  }

  scrollIntoView(el) {
    const elemTop = el.getBoundingClientRect().top;
    const elemBottom = el.getBoundingClientRect().bottom;

    const margin = 50;
    const top_margin = margin;
    const bottom_margin = margin + $('#bottom-bar').height();

    if (elemTop < top_margin) {
      // scroll up
      return this.scrollMain(elemTop - top_margin);
    } else if (elemBottom > window.innerHeight - bottom_margin) {
      // scroll down
      return this.scrollMain(elemBottom - window.innerHeight + bottom_margin);
    }
  }

  async getVisiblePaths() {
    const paths = [];
    $.makeArray($('.bullet')).forEach((bullet) => {
      if (!utils.isScrolledIntoView($(bullet), this.mainDiv)) {
        return;
      }
      if ($(bullet).hasClass('fa-clone')) {
        return;
      }
      // NOTE: can't use $(x).data
      // http://stackoverflow.com/questions/25876274/jquery-data-not-working
      const ancestry = $(bullet).attr('data-ancestry');
      if (!ancestry) { // as far as i know, this only happens because of menu mode
        return;
      }
      const path = Path.loadFromAncestry(JSON.parse(ancestry));
      paths.push(path);
    });
    return paths;
  }
}
