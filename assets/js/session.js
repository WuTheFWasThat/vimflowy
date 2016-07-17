/* globals $, document, window */
import _ from 'lodash';

import * as mutations from './mutations';
import * as constants from './constants';
import * as utils from './utils';
import * as errors from './errors';
import Cursor from './cursor';
import Register from './register';
import * as Logger from './logger';
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

class Session extends EventEmitter {
  constructor(doc, options = {}) {
    super();

    this.document = doc;

    this.bindings = options.bindings;
    this.settings = options.settings;
    // session needs to know div for page scrolling, getting visible rows
    this.mainDiv = options.mainDiv;
    this.messageDiv = options.messageDiv;
    this.menuDiv = options.menuDiv;

    this.register = new Register(this);

    // TODO: if we ever support multi-user case, ensure last view root is valid
    this.viewRoot = Path.loadFromAncestry((this.document.store.getLastViewRoot() || []));
    if (!(this.document.hasChildren(this.document.root.row))) {
      this.document.load(constants.empty_data);
    }

    let path;
    if (this.viewRoot.is(this.document.root)) {
      path = (this.document.getChildren(this.viewRoot))[0];
    } else {
      path = this.viewRoot;
    }
    this.cursor = new Cursor(this, path, 0);

    this.reset_history();
    this.reset_jump_history();

    this.setMode(MODES.NORMAL);
    return this;
  }

  exit() {
    return this.emit('exit');
  }

  //################
  // modes related
  //################

  setMode(newmode) {
    if (newmode === this.mode) {
      return;
    }

    let oldmode = this.mode;
    if (oldmode) {
      (Modes.getMode(oldmode)).exit(this, newmode);
    }

    this.mode = newmode;
    (Modes.getMode(this.mode)).enter(this, oldmode);

    return this.emit('modeChange', oldmode, newmode);
  }

  toggleBindingsDiv() {
    return this.emit('toggleBindingsDiv');
  }

  //################
  // show message
  //################

  showMessage(message, options = {}) {
    if (options.time === undefined) { options.time = 5000; }
    Logger.logger.info(`Showing message: ${message}`);
    if (this.messageDiv) {
      clearTimeout(this.messageDivTimeout);

      this.messageDiv.text(message);
      if (options.text_class) {
        this.messageDiv.addClass(`text-${options.text_class}`);
      }

      return this.messageDivTimeout = setTimeout(() => {
        this.messageDiv.text('');
        return this.messageDiv.removeClass();
      }, options.time);
    }
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
    let verify = function(node) {
      if (node.clone) {
        return true;
      }
      if (!node.text && node.text !== '') { return false; }
      if (node.children) {
        for (let i = 0; i < node.children.length; i++) {
          let child = node.children[i];
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
    let whitespace = /^\s*/;
    let content_lines = content.split('\n');
    for (let i = 0; i < content_lines.length; i++) {
      let line = content_lines[i];
      if (line.match(/^\s*".*"$/)) { // Flag workflowy annotations as special cases
        lines.push({
          indent: (line.match(whitespace))[0].length,
          line: line.replace(/^\s*"(.*)"$/, '$1'),
          annotation: true
        });
        continue;
      }
      // TODO: record whether COMPLETE and strikethrough line if so?
      lines.push({
        indent: (line.match(whitespace))[0].length,
        line: (line.replace(whitespace, '')).replace(/^(?:-\s*)?(?:\[COMPLETE\] )?/, '')
      });
    }
    while (lines[lines.length-1].line === '') { // Strip trailing blank line(s)
      lines = lines.splice(0, lines.length-1);
    }

    // Step 2: convert a list of (int, string, annotation?) into a forest format
    let parseAllChildren = function(parentIndentation, lineNumber) {
      let children = [];
      if (lineNumber < lines.length && lines[lineNumber].annotation) {
        // Each node can have an annotation immediately follow it
        children.push({
          text: lines[lineNumber].line});
        lineNumber = lineNumber + 1;
      }
      while (lineNumber < lines.length && lines[lineNumber].indent > parentIndentation) {
        // For [the first line of] each child
        let child =
          {text: lines[lineNumber].line};
        let result = parseAllChildren(lines[lineNumber].indent, lineNumber + 1);
        ({ lineNumber } = result);
        if (result.children !== null) {
          child.children = result.children;
          child.collapsed = result.children.length > 0;
        }
        children.push(child);
      }
      return { children, lineNumber};
    };
    let forest = (parseAllChildren(-1, 0)).children;
    let root = {
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
  importContent(content, mimetype) {
    let root = this.parseContent(content, mimetype);
    if (!root) { return false; }
    let { path } = this.cursor;
    if (root.text === '' && root.children) { // Complete export, not one node
      this.addBlocks(path, 0, root.children);
    } else {
      this.addBlocks(path, 0, [root]);
    }
    this.save();
    this.emit('importFinished');
    return true;
  }

  exportContent(mimetype) {
    let jsonContent = this.document.serialize();
    if (mimetype === 'application/json') {
      delete jsonContent.viewRoot;
      return JSON.stringify(jsonContent, undefined, 2);
    } else if (mimetype === 'text/plain') {
      // Workflowy compatible plaintext export
      //   Ignores 'collapsed' and viewRoot
      let indent = '  ';
      let exportLines = function(node) {
        if (typeof(node) === 'string') {
          return [`- ${node}`];
        }
        let lines = [];
        lines.push(`- ${node.text}`);
        let children = node.children || [];
        for (let i = 0; i < children.length; i++) {
          let child = children[i];
          if (child.clone) {
            continue;
          }
          exportLines(child).forEach((line) => {
            lines.push(`${indent}${line}`);
          });
        }
        return lines;
      };
      return (exportLines(jsonContent)).join('\n');
    } else {
      throw new errors.UnexpectedValue('mimetype', mimetype);
    }
  }

  //################
  // MUTATIONS
  //################

  reset_history() {
    this.mutations = []; // full mutation history
    this.history = [{
      index: 0
    }];
    return this.historyIndex = 0; // index into indices
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

    let state = this.history[this.historyIndex];
    state.after = {
      cursor: this.cursor.clone(),
      viewRoot: this.viewRoot
    };

    this.historyIndex += 1;
    return this.history.push({
      index: this.mutations.length
    });
  }

  restoreViewState(state) {
    this.cursor.from(state.cursor);
    this.fixCursorForMode();
    return this.changeView(state.viewRoot);
  }

  undo() {
    if (this.historyIndex > 0) {
      let oldState = this.history[this.historyIndex];
      this.historyIndex -= 1;
      let newState = this.history[this.historyIndex];

      Logger.logger.debug('UNDOING <');
      for (let j = oldState.index - 1; j > newState.index - 1; j--) {
        let mutation = this.mutations[j];
        Logger.logger.debug(`  Undoing mutation ${mutation.constructor.name}(${mutation.str()})`);
        let undo_mutations = mutation.rewind(this);
        for (let k = 0; k < undo_mutations.length; k++) {
          let undo_mutation = undo_mutations[k];
          Logger.logger.debug(`  Undo mutation ${undo_mutation.constructor.name}(${undo_mutation.str()})`);
          undo_mutation.mutate(this);
          undo_mutation.moveCursor(this.cursor);
        }
      }

      Logger.logger.debug('> END UNDO');
      return this.restoreViewState(newState.before);
    }
  }

  redo() {
    if (this.historyIndex < this.history.length - 1) {
      let oldState = this.history[this.historyIndex];
      this.historyIndex += 1;
      let newState = this.history[this.historyIndex];

      Logger.logger.debug('REDOING <');
      for (let j = oldState.index; j < newState.index; j++) {
        let mutation = this.mutations[j];
        Logger.logger.debug(`  Redoing mutation ${mutation.constructor.name}(${mutation.str()})`);
        if (!mutation.validate(this)) {
          // this should not happen, since the state should be the same as before
          throw new errors.GenericError(`Failed to redo mutation: ${mutation.str()}`);
        }
        mutation.remutate(this);
        mutation.moveCursor(this.cursor);
      }
      Logger.logger.debug('> END REDO');
      return this.restoreViewState(oldState.after);
    }
  }

  do(mutation) {
    if (!this.history) {
      // NOTE: we let mutations through since some plugins may apply mutations on load
      // these mutations won't be undoable, which is desired
      Logger.logger.warn(`Tried mutation ${mutation} before init!`);
      mutation.mutate(this);
      return true;
    }

    if (this.historyIndex !== this.history.length - 1) {
      this.history = this.history.slice(0, (this.historyIndex + 1));
      this.mutations = this.mutations.slice(0, this.history[this.historyIndex].index);
    }

    let state = this.history[this.historyIndex];
    if (this.mutations.length === state.index) {
      state.before = {
        cursor: this.cursor.clone(),
        viewRoot: this.viewRoot
      };
    }

    Logger.logger.debug(`Applying mutation ${mutation.constructor.name}(${mutation.str()})`);
    if (!mutation.validate(this)) {
      return false;
    }
    mutation.mutate(this);
    mutation.moveCursor(this.cursor);
    // TODO: do this elsewhere
    this.fixCursorForMode();

    this.mutations.push(mutation);
    return true;
  }

  fixCursorForMode() {
    if ((Modes.getMode(this.mode)).metadata.hotkey_type !== Modes.INSERT_MODE_TYPE) {
      return this.cursor.backIfNeeded();
    }
  }

  //#################
  // viewability
  //#################

  // whether contents are currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable(path) {
    return (!this.document.collapsed(path.row)) || (path.is(this.viewRoot));
  }

  nextVisible(path) {
    if (this.viewable(path)) {
      let children = this.document.getChildren(path);
      if (children.length > 0) {
        return children[0];
      }
    }
    if (path.is(this.viewRoot)) {
      return null;
    }
    while (true) {
      let nextsib = this.document.getSiblingAfter(path);
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
    let children = this.document.getChildren(path);
    if (children.length > 0) {
      return this.lastVisible(children[children.length - 1]);
    }
    return path;
  }

  prevVisible(path) {
    if (path.is(this.viewRoot)) {
      return null;
    }
    let prevsib = this.document.getSiblingBefore(path);
    if (prevsib !== null) {
      return this.lastVisible(prevsib);
    }
    let { parent } = path;
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
      let cur = last.parent;
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
    let visibleAncestor = this.youngestVisibleAncestor(path);
    return (visibleAncestor !== null) && (path.is(visibleAncestor));
  }

  //#################
  // View root
  //#################

  _changeViewRoot(path) {
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

  addToJumpHistory(jump_fn) {
    let jump = this.jumpHistory[this.jumpIndex];
    jump.cursor_after = this.cursor.clone();

    this.jumpHistory = this.jumpHistory.slice(0, (this.jumpIndex+1));

    jump_fn();

    this.jumpHistory.push({
      viewRoot: this.viewRoot,
      cursor_before: this.cursor.clone()
    });
    return this.jumpIndex += 1;
  }

  // try going to jump, return true if succeeds
  tryJump(jump) {
    if (jump.viewRoot.row === this.viewRoot.row) {
      return false; // not moving, don't jump
    }

    if (!this.document.isAttached(jump.viewRoot.row)) {
      return false; // invalid location
    }

    let children = this.document.getChildren(jump.viewRoot);

    this._changeViewRoot(jump.viewRoot);
    if (children.length) {
      this.cursor.setPath(children[0]);
    } else {
      this.cursor.setPath(jump.viewRoot);
    }

    if (this.document.isAttached(jump.cursor_after.row)) {
      // if the row is attached and under the view root, switch to it
      let cursor_path = this.youngestVisibleAncestor(jump.cursor_after.path);
      if (cursor_path !== null) {
        this.cursor.setPath(cursor_path);
      }
    }
    return true;
  }

  jumpPrevious() {
    let { jumpIndex } = this;

    let jump = this.jumpHistory[jumpIndex];
    jump.cursor_after = this.cursor.clone();

    while (true) {
      if (jumpIndex === 0) {
        return false;
      }
      jumpIndex -= 1;
      let oldjump = this.jumpHistory[jumpIndex];
      if (this.tryJump(oldjump)) {
        this.jumpIndex = jumpIndex;
        return true;
      }
    }
  }

  jumpNext() {
    let { jumpIndex } = this;

    let jump = this.jumpHistory[jumpIndex];
    jump.cursor_after = this.cursor.clone();

    while (true) {
      if (jumpIndex === this.jumpHistory.length - 1) {
        return false;
      }
      jumpIndex += 1;
      let newjump = this.jumpHistory[jumpIndex];
      if (this.tryJump(newjump)) {
        this.jumpIndex = jumpIndex;
        return true;
      }
    }
  }

  // try to change the view root to row
  // fails if there is no child
  // records in jump history
  changeView(path) {
    if (path.row === this.viewRoot.row) {
      return; // not moving, do nothing
    }
    return this.addToJumpHistory(() => {
      return this._changeViewRoot(path);
    });
  }

  // try to zoom into newroot, updating the cursor
  zoomInto(newroot) {
    this.changeView(newroot);
    let newrow = this.youngestVisibleAncestor(this.cursor.path);
    if (newrow === null) { // not visible, need to reset cursor
      newrow = newroot;
    }
    return this.cursor.setPath(newrow);
  }

  zoomOut() {
    if (this.viewRoot.row !== this.document.root.row) {
      let { parent } = this.viewRoot;
      return this.zoomInto(parent);
    }
  }

  zoomIn() {
    if (this.cursor.path.is(this.viewRoot)) {
      return false;
    }
    let newroot = this.oldestVisibleAncestor(this.cursor.path);
    if (this.zoomInto(newroot)) {
      return true;
    }
    return false;
  }

  zoomDown() {
    let sib = this.document.getSiblingAfter(this.viewRoot);
    if (sib === null) {
      this.showMessage('No next sibling to zoom down to', {text_class: 'error'});
      return;
    }
    return this.zoomInto(sib);
  }

  zoomUp() {
    let sib = this.document.getSiblingBefore(this.viewRoot);
    if (sib === null) {
      this.showMessage('No previous sibling to zoom up to', {text_class: 'error'});
      return;
    }
    return this.zoomInto(sib);
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
    let { col } = this.cursor;
    if (col < (this.document.getLength(this.cursor.row))) {
      col += 1;
    }
    return this.addChars(this.cursor.row, col, chars);
  }

  delChars(path, col, nchars, options = {}) {
    let n = this.document.getLength(path.row);
    let deleted = [];
    if ((n > 0) && (nchars > 0) && (col < n)) {
      let mutation = new mutations.DelChars(path.row, col, nchars);
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
    let mutation = new mutations.ChangeChars(row, col, nchars, change_fn);
    this.do(mutation);
    return mutation.ncharsDeleted;
  }

  replaceCharsAfterCursor(char, nchars) {
    let ndeleted = this.changeChars(this.cursor.row, this.cursor.col, nchars, (chars =>
      chars.map((function(char_obj) {
        let new_obj = _.clone(char_obj);
        new_obj.char = char;
        return new_obj;
      })
      )
    )
    );
    return this.cursor.setCol(((this.cursor.col + ndeleted) - 1));
  }

  clearRowAtCursor(options) {
    if (options.yank) {
      // yank as a row, not chars
      this.yankRowAtCursor();
    }
    return this.delChars(this.cursor.path, 0, (this.curLineLength()));
  }

  yankChars(path, col, nchars) {
    let line = this.document.getLine(path.row);
    if (line.length > 0) {
      return this.register.saveChars(line.slice(col, col + nchars));
    }
  }

  // options:
  //   - includeEnd says whether to also delete cursor2 location
  yankBetween(cursor1, cursor2, options = {}) {
    if (!(cursor2.path.is(cursor1.path))) {
      Logger.logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }

    let offset = options.includeEnd ? 1 : 0;
    return this.yankChars(cursor1.path, cursor1.col, ((cursor2.col - cursor1.col) + offset));
  }

  yankRowAtCursor() {
    let serialized_row = this.document.serializeRow(this.cursor.row);
    return this.register.saveSerializedRows([serialized_row]);
  }

  // options:
  //   - includeEnd says whether to also delete cursor2 location
  deleteBetween(cursor1, cursor2, options = {}) {
    if (!(cursor2.path.is(cursor1.path))) {
      Logger.logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }
    let offset = options.includeEnd ? 1 : 0;
    return this.delChars(cursor1.path, cursor1.col, ((cursor2.col - cursor1.col) + offset), options);
  }

  // TODO: fix a bunch of these to use rows (they're still actually paths)

  // toggling text properties
  // if new_value is null, should be inferred based on old values
  toggleProperty(property, new_value, row, col, n) {
    return this.changeChars(row, col, n, (function(deleted) {
      if (new_value === null) {
        let all_were_true = _.every(deleted.map((obj => obj[property])));
        new_value = !all_were_true;
      }

      return deleted.map((function(char_obj) {
        let new_obj = _.clone(char_obj);
        new_obj[property] = new_value;
        return new_obj;
      })
      );
    })
    );
  }

  toggleRowsProperty(property, rows) {
    let all_were_true = _.every(rows.map((row => {
      return _.every((this.document.getLine(row)).map((obj => obj[property])));
    })));
    let new_value = !all_were_true;
    for (let i = 0; i < rows.length; i++) {
      let row = rows[i];
      this.toggleProperty(property, new_value, row, 0, (this.document.getLength(row)));
    }
    return null;
  }

  toggleRowProperty(property, row = this.cursor.row) {
    return this.toggleProperty(property, null, row, 0, (this.document.getLength(row)));
  }

  toggleRowPropertyBetween(property, cursor1, cursor2, options) {
    if (!(cursor2.path.is(cursor1.path))) {
      Logger.logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }

    let offset = options.includeEnd ? 1 : 0;
    return this.toggleProperty(property, null, cursor1.row, cursor1.col, ((cursor2.col - cursor1.col) + offset));
  }

  newLineBelow(options = {}) {
    options.setCursor = 'first';

    if (this.cursor.path.is(this.viewRoot)) {
      if (!(this.document.hasChildren(this.cursor.row))) {
        if (!this.document.collapsed(this.cursor.row)) {
          this.toggleBlockCollapsed(this.cursor.row);
        }
      }

      return this.addBlocks(this.cursor.path, 0, [''], options);
    } else if ((!this.document.collapsed(this.cursor.row)) && this.document.hasChildren(this.cursor.row)) {
      return this.addBlocks(this.cursor.path, 0, [''], options);
    } else {
      let { parent } = this.cursor.path;
      let index = this.document.indexOf(this.cursor.path);
      return this.addBlocks(parent, (index+1), [''], options);
    }
  }

  newLineAbove() {
    if (this.cursor.path.is(this.viewRoot)) {
      return;
    }
    let { parent } = this.cursor.path;
    let index = this.document.indexOf(this.cursor.path);
    return this.addBlocks(parent, index, [''], {setCursor: 'first'});
  }

  // behavior of "enter", splitting a line
  // If enter is not at the end:
  //     insert a new node before with the first half of the content
  //     note that this will always preserve child-parent relationships
  // If enter is at the end:
  //     insert a new node after
  //     if the node has children, this is the new first child
  newLineAtCursor() {
    if (this.cursor.col === this.document.getLength(this.cursor.row)) {
      return this.newLineBelow({cursorOptions: {keepProperties: true}});
    } else {
      let mutation = new mutations.DelChars(this.cursor.row, 0, this.cursor.col);
      this.do(mutation);
      let { path } = this.cursor;

      this.newLineAbove();
      // cursor now is at inserted path, add the characters
      this.addCharsAfterCursor(mutation.deletedChars);
      // restore cursor
      return this.cursor.set(path, 0, {keepProperties: true});
    }
  }

  // can only join if either:
  // - first is previous sibling of second, AND has no children
  // - second is first child of first, AND has no children
  joinRows(first, second, options = {}) {
    let addDelimiter = false;
    let firstLine = this.document.getLine(first.row);
    let secondLine = this.document.getLine(second.row);
    if (options.delimiter) {
      if (firstLine.length && secondLine.length) {
        if (firstLine[firstLine.length - 1].char !== options.delimiter) {
          if (secondLine[0].char !== options.delimiter) {
            addDelimiter = true;
          }
        }
      }
    }

    if (!(this.document.hasChildren(second.row))) {
      this.cursor.set(first, -1);
      this.delBlock(second, {noNew: true, noSave: true});
      if (addDelimiter) {
        let mutation = new mutations.AddChars(first.row, firstLine.length, [{ char: options.delimiter }]);
        this.do(mutation);
      }
      let mutation = new mutations.AddChars(first.row, (firstLine.length + addDelimiter), secondLine);
      this.do(mutation);
      this.cursor.set(first, firstLine.length);
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

    this.cursor.set(second, 0);
    this.delBlock(first, {noNew: true, noSave: true});
    if (addDelimiter) {
      let mutation = new mutations.AddChars(second.row, 0, [{ char: options.delimiter }]);
      this.do(mutation);
    }
    let mutation = new mutations.AddChars(second.row, 0, firstLine);
    this.do(mutation);

    if (addDelimiter) {
      this.cursor.left();
    }

    return true;
  }

  joinAtCursor() {
    let { path } = this.cursor;
    let sib = this.nextVisible(path);
    if (sib !== null) {
      return this.joinRows(path, sib, {delimiter: ' '});
    }
  }

  // implements proper "backspace" behavior
  deleteAtCursor() {
    if (this.cursor.col > 0) {
      this.delCharsBeforeCursor(1, {cursor: {pastEnd: true}});
      return true;
    }

    let { path } = this.cursor;
    let sib = this.prevVisible(path);
    if (sib === null) {
      return false;
    }

    if (this.joinRows(sib, path)) {
      return true;
    }

    return false;
  }

  delBlock(path, options) {
    return this.delBlocks(path.parent.row, (this.document.indexOf(path)), 1, options);
  }

  delBlocks(parent, index, nrows, options = {}) {
    let mutation = new mutations.DetachBlocks(parent, index, nrows, options);
    this.do(mutation);
    if (!options.noSave) {
      this.register.saveClonedRows(mutation.deleted);
    }
    if (!(this.isVisible(this.cursor.path))) {
      // view root got deleted
      return this.zoomOut();
    }
  }

  delBlocksAtCursor(nrows, options = {}) {
    let { parent } = this.cursor.path;
    let index = this.document.indexOf(this.cursor.path);
    return this.delBlocks(parent.row, index, nrows, options);
  }

  addBlocks(parent, index = -1, serialized_rows, options = {}) {
    let mutation = new mutations.AddBlocks(parent, index, serialized_rows, options);
    this.do(mutation);
    if (options.setCursor === 'first') {
      return this.cursor.set(mutation.added_rows[0], 0, options.cursorOptions);
    } else if (options.setCursor === 'last') {
      return this.cursor.set(mutation.added_rows[mutation.added_rows.length - 1], 0, options.cursorOptions);
    }
  }

  yankBlocks(path, nrows) {
    let siblings = this.document.getSiblingRange(path, 0, (nrows-1));
    siblings = siblings.filter((x => x !== null));
    let serialized = siblings.map((x => { return this.document.serialize(x.row); }));
    return this.register.saveSerializedRows(serialized);
  }

  yankBlocksAtCursor(nrows) {
    return this.yankBlocks(this.cursor.path, nrows);
  }

  yankBlocksClone(row, nrows) {
    let siblings = this.document.getSiblingRange(row, 0, (nrows-1));
    siblings = siblings.filter((x => x !== null));
    return this.register.saveClonedRows((siblings.map(sibling => sibling.row)));
  }

  yankBlocksCloneAtCursor(nrows) {
    return this.yankBlocksClone(this.cursor.path, nrows);
  }

  attachBlocks(parent, ids, index = -1, options = {}) {
    let mutation = new mutations.AttachBlocks(parent.row, ids, index, options);
    let will_work = mutation.validate(this);
    this.do(mutation);

    // TODO: do this more elegantly
    if (will_work) {
      if (options.setCursor === 'first') {
        return this.cursor.set((this.document.findChild(parent, ids[0])), 0);
      } else if (this.options.setCursor === 'last') {
        return this.cursor.set((this.document.findChild(parent, ids[ids.length-1])), 0);
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
    let newparent = this.document.getSiblingBefore(row);
    if (newparent === null) {
      this.showMessage('Cannot indent without higher sibling', {text_class: 'error'});
      return null; // cannot indent
    }

    if (this.document.collapsed(newparent.row)) {
      this.toggleBlockCollapsed(newparent.row);
    }

    let siblings = (this.document.getSiblingRange(row, 0, (numblocks-1))).filter((sib => sib !== null));
    for (let i = 0; i < siblings.length; i++) {
      let sib = siblings[i];
      this.moveBlock(sib, newparent, -1);
    }
    return newparent;
  }

  unindentBlocks(row, numblocks = 1) {
    if (row.is(this.viewRoot)) {
      this.showMessage('Cannot unindent view root', {text_class: 'error'});
      return;
    }
    let { parent } = row;
    if (parent.row === this.viewRoot.row) {
      this.showMessage('Cannot unindent past root', {text_class: 'error'});
      return null;
    }

    let siblings = (this.document.getSiblingRange(row, 0, (numblocks-1))).filter((sib => sib !== null));

    let newparent = parent.parent;
    let pp_i = this.document.indexOf(parent);

    for (let i = 0; i < siblings.length; i++) {
      let sib = siblings[i];
      pp_i += 1;
      this.moveBlock(sib, newparent, pp_i);
    }
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

    let sib = this.document.getSiblingBefore(path);

    let newparent = this.indentBlocks(path);
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

    let { parent } = path;
    let p_i = this.document.indexOf(path);

    let newparent = this.unindentBlocks(path);
    if (newparent === null) {
      return;
    }

    let p_children = this.document.getChildren(parent);
    p_children.slice(p_i).forEach((child) => {
      this.moveBlock(child, path, -1);
    });
  }

  swapDown(path = this.cursor.path) {
    let next = this.nextVisible(this.lastVisible(path));
    if (next === null) {
      return;
    }

    if ((this.document.hasChildren(next.row)) && (!this.document.collapsed(next.row))) {
      // make it the first child
      return this.moveBlock(path, next, 0);
    } else {
      // make it the next sibling
      let { parent } = next;
      let p_i = this.document.indexOf(next);
      return this.moveBlock(path, parent, (p_i+1));
    }
  }

  swapUp(path = this.cursor.path) {
    let prev = this.prevVisible(path);
    if (prev === null) {
      return;
    }

    // make it the previous sibling
    let { parent } = prev;
    let p_i = this.document.indexOf(prev);
    return this.moveBlock(path, parent, p_i);
  }

  toggleCurBlockCollapsed() {
    return this.toggleBlockCollapsed(this.cursor.row);
  }

  toggleBlockCollapsed(row) {
    return this.do(new mutations.ToggleBlock(row));
  }

  pasteBefore() {
    return this.register.paste({before: true});
  }

  pasteAfter() {
    return this.register.paste({});
  }

  // given an anchor and cursor, figures out the right blocks to be deleting
  // returns a parent, minindex, and maxindex
  getVisualLineSelections() {
    let [common, ancestors1, ancestors2] = this.document.getCommonAncestor(this.cursor.path, this.anchor.path);
    if (ancestors1.length === 0) {
      // anchor is underneath cursor
      let { parent } = common;
      let index = this.document.indexOf(this.cursor.path);
      return [parent, index, index];
    } else if (ancestors2.length === 0) {
      // cursor is underneath anchor
      let { parent } = common;
      let index = this.document.indexOf(this.anchor.path);
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

  scroll(npages) {
    this.emit('scroll', npages);
    // TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
    let line_height = $('.node-text').height() || 21;
    errors.assert((line_height > 0));
    let page_height = $(document).height();
    let height = npages * page_height;

    let numlines = Math.round(height / line_height);
    numlines = Math.max(Math.min(numlines, 1000), -1000); // guard against craziness

    if (numlines > 0) {
      for (let j = 0; j < numlines; j++) {
        this.cursor.down();
      }
    } else {
      for (let j = 0; j < -numlines; j++) {
        this.cursor.up();
      }
    }

    return this.scrollMain((line_height * numlines));
  }

  scrollMain(amount) {
    // # animate.  seems to not actually be great though
    // @mainDiv.stop().animate({
    //     scrollTop: @mainDiv[0].scrollTop + amount
    //  }, 50)
    return this.mainDiv.scrollTop(this.mainDiv.scrollTop() + amount);
  }

  scrollIntoView(el) {
    let elemTop = el.getBoundingClientRect().top;
    let elemBottom = el.getBoundingClientRect().bottom;

    let margin = 50;
    let top_margin = margin;
    let bottom_margin = margin + $('#bottom-bar').height();

    if (elemTop < top_margin) {
      // scroll up
      return this.scrollMain((elemTop - top_margin));
    } else if (elemBottom > window.innerHeight - bottom_margin) {
      // scroll down
      return this.scrollMain ((elemBottom - window.innerHeight) + bottom_margin);
    }
  }

  getVisiblePaths() {
    let paths = [];
    $.makeArray($('.bullet')).forEach((bullet) => {
      if (!(utils.isScrolledIntoView($(bullet), this.mainDiv))) {
        return;
      }
      if ($(bullet).hasClass('fa-clone')) {
        return;
      }
      // NOTE: can't use $(x).data
      // http://stackoverflow.com/questions/25876274/jquery-data-not-working
      let ancestry = $(bullet).attr('data-ancestry');
      if (!ancestry) { // as far as i know, this only happens because of menu mode
        return;
      }
      let path = Path.loadFromAncestry(JSON.parse(ancestry));
      paths.push(path);
    });
    return paths;
  }
}

// exports
export default Session;
