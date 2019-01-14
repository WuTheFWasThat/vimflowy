import * as browser_utils from './utils/browser';
import * as errors from '../../shared/utils/errors';
import EventEmitter from './utils/eventEmitter';
import logger from '../../shared/utils/logger';
import { ClientStore } from './datastore';
import { SynchronousInMemory } from '../../shared/data_backend';
import * as mutations from './mutations';
import Cursor from './cursor';
import Register from './register';
import Path from './path';
import Document, { InMemoryDocument } from './document';
import Mutation from './mutations';
import Menu from './menu';

import * as Modes from './modes';

import { ModeId, CursorOptions, Row, Col, Chars, SerializedBlock } from './types';

type SessionOptions = {
  initialMode?: ModeId,
  viewRoot?: Path,
  cursorPath?: Path,
  showMessage?: (message: string, options?: any) => void,
  toggleBindingsDiv?: () => void,
  getLinesPerPage?: () => number,
};
type ViewState = {
  cursor: Cursor,
  viewRoot: Path,
};
type HistoryLogEntry = {
  index: number,
  after?: ViewState,
  before?: ViewState,
};
type JumpLogEntry = {
  viewRoot: Path,
  cursor_before: Cursor,
  cursor_after?: Cursor,
};

type DelCharsOptions = {
  yank?: boolean,
};

type DelBlockOptions = {
  noSave?: boolean,
  addNew?: boolean,
  noNew?: boolean,
};

/*
a Session represents a session with a vimflowy document
It holds a Cursor, a Document object
It exposes methods for manipulation of the document, and movement of the cursor

Currently, the separation between the Session and Document classes is not very good.  (see document.ts)
Ideally, session shouldn't do much more than handle cursors and history
*/

export default class Session extends EventEmitter {
  public mode: ModeId;

  public clientStore: ClientStore;
  public document: Document;
  public register: Register;
  public cursor: Cursor;
  private _anchor: Cursor | null;

  public viewRoot: Path;

  public menu: Menu | null = null;

  private mutations: Array<Mutation> = [];
  private history: Array<HistoryLogEntry> = [];
  private historyIndex: number = 0;
  public jumpHistory: Array<JumpLogEntry> = [];
  public jumpIndex: number = 0;

  private getLinesPerPage: () => number;
  public showMessage: (message: string, options?: any) => void;
  public toggleBindingsDiv: () => void;

  private static swapCase(chars: Chars) {
    return chars.map(function(chr) {
      return chr.toLowerCase() === chr ? chr.toUpperCase() : chr.toLowerCase();
    });
  }
  constructor(clientStore: ClientStore, doc: Document, options: SessionOptions = {}) {
    super();

    this.clientStore = clientStore;

    this.document = doc;

    this.showMessage = options.showMessage || ((message) => {
      logger.info(`Showing message: ${message}`);
    });
    this.toggleBindingsDiv = options.toggleBindingsDiv || (() => null);
    this.getLinesPerPage = options.getLinesPerPage || (() => 10);

    this.register = new Register(this);

    this.menu = null;

    this.viewRoot = options.viewRoot || Path.root();
    this.cursor = new Cursor(this, options.cursorPath || this.viewRoot, 0);
    this._anchor = null;

    this.reset_history();
    this.reset_jump_history();

    const mode = options.initialMode || 'NORMAL';
    // NOTE: this is fire and forget
    // this.setMode(mode);
    this.mode = mode;
    return this;
  }

  public async exit() {
    await this.emitAsync('exit');
  }

  public async setMode(newmode: ModeId) {
    if (newmode === this.mode) {
      return;
    }

    const oldmode = this.mode;
    if (oldmode) {
      await Modes.getMode(oldmode).exit(this, newmode);
    }

    this.mode = newmode;
    await Modes.getMode(this.mode).enter(this, oldmode);

    this.emit('modeChange', oldmode, newmode);
  }

  ////////////////////////////////
  // import/export
  ////////////////////////////////

  private parseJson(content: string) {
    let root;
    try {
      root = JSON.parse(content);
    } catch (error) {
      this.showMessage('The uploaded file is not valid JSON', {text_class: 'error'});
      return false;
    }
    const verify = function(node: any) {
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

  private parsePlaintext(content: string) {
    // Step 1: parse into (int, string) pairs of indentation amounts.
    let lines: Array<{
      indent: number,
      line: string,
      annotation?: boolean,
    }> = [];
    const whitespace = /^\s*/;
    const content_lines = content.split('\n');
    content_lines.forEach((line) => {
      const matches = line.match(whitespace);
      const indent = matches ? matches[0].length : 0;
      if (line.match(/^\s*".*"$/)) { // Flag workflowy annotations as special cases
        lines.push({
          indent,
          line: line.replace(/^\s*"(.*)"$/, '$1'),
          annotation: true,
        });
      } else {
        // TODO: record whether COMPLETE and strikethrough line if so?
        lines.push({
          indent,
          line: line.replace(whitespace, '').replace(/^(?:-\s*)?(?:\[COMPLETE\] )?/, ''),
        });
      }
    });
    while (lines[lines.length - 1].line === '') { // Strip trailing blank line(s)
      lines = lines.splice(0, lines.length - 1);
    }

    // Step 2: convert a list of (int, string, annotation?) into a forest format
    const parseAllChildren = function(parentIndentation: number, lineNumber: number) {
      const children: Array<any> = [];
      if (lineNumber < lines.length && lines[lineNumber].annotation) {
        // Each node can have an annotation immediately follow it
        children.push({
          text: lines[lineNumber].line,
        });
        lineNumber = lineNumber + 1;
      }
      while (lineNumber < lines.length && lines[lineNumber].indent > parentIndentation) {
        // For [the first line of] each child
        const child: any = { text: lines[lineNumber].line };
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
      collapsed: forest.length > 0,
    };
    return root;
  }

  private parseContent(content: string, mimetype: string) {
    if (mimetype === 'application/json') {
      return this.parseJson(content);
    } else if (mimetype === 'text/plain' || mimetype === 'Text') {
      return this.parsePlaintext(content);
    } else {
      return null;
    }
  }

  // TODO: make this use replace_empty = true?
  public async importContent(content: string, mimetype: string) {
    const root = this.parseContent(content, mimetype);
    if (!root) { return false; }
    const { path } = this.cursor;
    if (root.text === '' && root.children) { // Complete export, not one node
      await this.addBlocks(path, 0, root.children);
    } else {
      await this.addBlocks(path, 0, [root]);
    }
    this.save();
    this.emit('importFinished');
    return true;
  }

  public async exportContent(mimetype: string) {
    const jsonContent = await this.document.serialize();
    if (mimetype === 'application/json') {
      return JSON.stringify(jsonContent, undefined, 2);
    } else if (mimetype === 'text/plain') {
      // Workflowy compatible plaintext export
      //   Ignores 'collapsed' and viewRoot
      const indent = '  ';
      const exportLines = function(node: any) {
        if (typeof(node) === 'string') {
          return [`- ${node}`];
        }
        const lines: Array<string> = [];
        lines.push(`- ${node.text}`);
        const children = node.children || [];
        children.forEach((child: any) => {
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

  public async exportFile(type = 'json') {
    this.showMessage('Exporting...', { time: 0 });
    const filename = this.document.name === '' ?
                   `vimflowy.${type}` :
                   `${this.document.name}.${type}` ;
    // Infer mimetype from file extension
    const mimetype = browser_utils.mimetypeLookup(filename);
    if (!mimetype) {
      throw new Error('Invalid export type');
    }
    const content = await this.exportContent(mimetype);
    browser_utils.downloadFile(filename, content, mimetype);
    this.showMessage(`Exported to ${filename}!`, {text_class: 'success'});
  }

  ////////////////////////////////
  // MUTATIONS
  ////////////////////////////////

  public reset_history() {
    this.mutations = []; // full mutation history
    this.history = [{
      index: 0,
    }];
    this.historyIndex = 0; // index into indices
  }

  public save() {
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
      viewRoot: this.viewRoot,
    };

    this.historyIndex += 1;
    this.history.push({
      index: this.mutations.length,
    });
  }

  private async _restoreViewState(state: ViewState) {
    await this.cursor.from(state.cursor);
    await this.fixCursorForMode();
    await this.changeView(state.viewRoot);
  }

  public async undo() {
    if (this.historyIndex > 0) {
      const oldState = this.history[this.historyIndex];
      this.historyIndex -= 1;
      const newState = this.history[this.historyIndex];

      logger.debug('UNDOING <');
      for (let j = oldState.index - 1; j > newState.index - 1; j--) {
        const mutation = this.mutations[j];
        logger.debug(`  Undoing mutation ${mutation.constructor.name}(${mutation.str()})`);
        const undo_mutations = await mutation.rewind(this);
        for (let k = 0; k < undo_mutations.length; k++) {
          const undo_mutation = undo_mutations[k];
          logger.debug(`  Undo mutation ${undo_mutation.constructor.name}(${undo_mutation.str()})`);
          await undo_mutation.mutate(this);
          await undo_mutation.moveCursor(this.cursor);
        }
      }

      logger.debug('> END UNDO');
      if (!newState.before) {
        throw new Error('No previous cursor state found while undoing');
      }
      await this._restoreViewState(newState.before);
    }
  }

  public async redo() {
    if (this.historyIndex < this.history.length - 1) {
      const oldState = this.history[this.historyIndex];
      this.historyIndex += 1;
      const newState = this.history[this.historyIndex];

      logger.debug('REDOING <');
      for (let j = oldState.index; j < newState.index; j++) {
        const mutation = this.mutations[j];
        if (!await mutation.validate(this)) {
          // this should not happen, since the state should be the same as before
          throw new errors.GenericError(`Failed to redo mutation: ${mutation.str()}`);
        }
        logger.debug(`  Redoing mutation ${mutation.constructor.name}(${mutation.str()})`);
        await mutation.remutate(this);
        await mutation.moveCursor(this.cursor);
      }
      logger.debug('> END REDO');
      if (!oldState.after) {
        throw new Error('No after cursor state found while redoing');
      }
      await this._restoreViewState(oldState.after);
    }
  }

  public async do(mutation: Mutation) {
    if (!this.history) {
      // NOTE: we let mutations through since some plugins may apply mutations on load
      // these mutations won't be undoable, which is desired
      logger.warn(`Tried mutation ${mutation} before init!`);
      await mutation.mutate(this);
      return true;
    }

    if (!await mutation.validate(this)) {
      return false;
    }

    if (this.historyIndex !== this.history.length - 1) {
      this.history = this.history.slice(0, this.historyIndex + 1);
      this.mutations = this.mutations.slice(0, this.history[this.historyIndex].index);
    }

    const state = this.history[this.historyIndex];
    if (this.mutations.length === state.index) {
      state.before = {
        cursor: this.cursor.clone(),
        viewRoot: this.viewRoot,
      };
    }

    logger.debug(`Applying mutation ${mutation.constructor.name}(${mutation.str()})`);
    await mutation.mutate(this);
    await mutation.moveCursor(this.cursor);
    await this.fixCursorForMode();

    this.mutations.push(mutation);
    return true;
  }

  // TODO: do this in the mode
  private async fixCursorForMode() {
    if (!Modes.getMode(this.mode).metadata.cursorBetween) {
      await this.cursor.backIfNeeded();
    }
  }

  ////////////////////////////////
  // viewability
  ////////////////////////////////

  // whether contents are currently viewable (i.e. subtree is visible)
  public async viewable(path: Path) {
    return path.is(this.viewRoot) || (
            path.isDescendant(this.viewRoot) &&
            (!await this.document.collapsed(path.row))
           );
  }

  // whether a given path is visible
  public async isVisible(path: Path) {
    const visibleAncestor = await this.youngestVisibleAncestor(path);
    return (visibleAncestor !== null) && path.is(visibleAncestor);
  }

  public async nextVisible(path: Path) {
    if (await this.viewable(path)) {
      const children = await this.document.getChildren(path);
      if (children.length > 0) {
        return children[0];
      }
    }
    if (path.is(this.viewRoot)) {
      return null;
    }
    while (true) {
      const nextsib = await this.document.getSiblingAfter(path);
      if (nextsib !== null) {
        return nextsib;
      }
      if (path.parent == null) {
        throw new Error('Did not encounter view root on way to root');
      }
      path = path.parent;
      if (path.is(this.viewRoot)) {
        return null;
      }
    }
  }

  // last thing visible nested within id
  public async lastVisible(path: Path = this.viewRoot): Promise<Path> {
    if (!(await this.viewable(path))) {
      return path;
    }
    const children = await this.document.getChildren(path);
    if (children.length > 0) {
      return await this.lastVisible(children[children.length - 1]);
    }
    return path;
  }

  public async prevVisible(path: Path) {
    if (path.parent == null) {
      return null;
    }
    if (path.is(this.viewRoot)) {
      return null;
    }
    const prevsib = await this.document.getSiblingBefore(path);
    if (prevsib !== null) {
      return await this.lastVisible(prevsib);
    }
    if (path.parent.is(this.viewRoot)) {
      if (path.parent.is(this.document.root)) {
        return null;
      } else {
        return this.viewRoot;
      }
    }
    return path.parent;
  }

  // finds oldest ancestor that is visible *besides viewRoot*
  // returns null if there is no visible ancestor (i.e. path is not under viewroot)
  public async oldestVisibleAncestor(path: Path) {
    let last = path;
    while (true) {
      if (last.parent == null) {
        return null;
      }
      const cur = last.parent;
      if (cur.is(this.viewRoot)) {
        return last;
      }
      last = cur;
    }
  }

  // finds closest ancestor that is visible
  // returns null if there is no visible ancestor (i.e. path is not under viewroot)
  public async youngestVisibleAncestor(path: Path) {
    let answer = path;
    let cur = path;
    while (true) {
      if (cur.is(this.viewRoot)) {
        return answer;
      }
      if (cur.parent == null) {
        return null;
      }
      if (await this.document.collapsed(cur.row)) {
        answer = cur;
      }
      cur = cur.parent;
    }
  }

  ////////////////////////////////
  // View root
  ////////////////////////////////

  public async changeViewRoot(path: Path) {
    this.viewRoot = path;
    this.emit('changeViewRoot', path);
  }

  public reset_jump_history() {
    this.jumpHistory = [{
      viewRoot: this.viewRoot,
      cursor_before: this.cursor.clone(),
    }];
    this.jumpIndex = 0; // index into jump history
  }

  // jump_fn is just some function that changes
  // viewRoot and cursor
  private async _addToJumpHistory(jump_fn: () => Promise<void>) {
    const jump = this.jumpHistory[this.jumpIndex];
    jump.cursor_after = this.cursor.clone();

    this.jumpHistory = this.jumpHistory.slice(0, this.jumpIndex + 1);

    await jump_fn();

    this.jumpHistory.push({
      viewRoot: this.viewRoot,
      cursor_before: this.cursor.clone(),
    });
    this.jumpIndex += 1;
  }

  // try going to jump, return true if succeeds
  private async tryJump(jump: JumpLogEntry) {
    if (jump.viewRoot.row === this.viewRoot.row) {
      return false; // not moving, don't jump
    }

    if (!await this.document.isAttached(jump.viewRoot.row)) {
      return false; // invalid location
    }

    const children = await this.document.getChildren(jump.viewRoot);

    await this.changeViewRoot(jump.viewRoot);
    if (children.length) {
      await this.cursor.setPath(children[0]);
    } else {
      await this.cursor.setPath(jump.viewRoot);
    }

    if (!jump.cursor_after) {
      throw new Error('Jump should have had cursor_after');
    }

    if (await this.document.isAttached(jump.cursor_after.row)) {
      // if the row is attached and under the view root, switch to it
      const cursor_path = await this.youngestVisibleAncestor(jump.cursor_after.path);
      if (cursor_path !== null) {
        await this.cursor.setPath(cursor_path);
      }
    }
    return true;
  }

  public async jumpPrevious() {
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

  public async jumpNext() {
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
  private async changeView(path: Path) {
    if (path.is(this.viewRoot)) {
      return; // not moving, do nothing
    }
    await this._addToJumpHistory(async () => {
      await this.changeViewRoot(path);
    });
  }

  // try to zoom into newroot, updating the cursor
  public async zoomInto(newroot: Path) {
    await this.changeView(newroot);
    let newpath = await this.youngestVisibleAncestor(this.cursor.path);
    if (newpath === null) { // not visible, need to reset cursor
      newpath = newroot;
    }
    await this.cursor.setPath(newpath);
  }

  public async zoomOut() {
    if (this.viewRoot.parent != null) {
      await this.zoomInto(this.viewRoot.parent);
    }
  }

  public async zoomIn() {
    if (this.cursor.path.is(this.viewRoot)) {
      return;
    }
    const newroot = await this.oldestVisibleAncestor(this.cursor.path);
    if (newroot == null) {
      throw new Error('Got error zooming in to cursor');
    }
    await this.zoomInto(newroot);
  }

  public async zoomDown() {
    const sib = await this.document.getSiblingAfter(this.viewRoot);
    if (sib === null) {
      this.showMessage('No next sibling to zoom down to', {text_class: 'error'});
      return;
    }
    await this.zoomInto(sib);
  }

  public async zoomUp() {
    const sib = await this.document.getSiblingBefore(this.viewRoot);
    if (sib === null) {
      this.showMessage('No previous sibling to zoom up to', {text_class: 'error'});
      return;
    }
    await this.zoomInto(sib);
  }

  ////////////////////////////////
  // Text
  ////////////////////////////////

  public async curLine() {
    return await this.document.getLine(this.cursor.row);
  }

  public async curText() {
    return await this.document.getText(this.cursor.row);
  }

  public async curLineLength() {
    return await this.document.getLength(this.cursor.row);
  }

  public async addChars(row: Row, col: Col, chars: Chars) {
    if (col < 0) {
      col = (await this.document.getLength(row)) + col + 1;
    }
    await this.do(new mutations.AddChars(row, col, chars));
  }

  public async addCharsAtCursor(chars: Chars) {
    await this.addChars(this.cursor.row, this.cursor.col, chars);
  }

  public async addCharsAfterCursor(chars: Chars) {
    let col = this.cursor.col;
    if (col < (await this.document.getLength(this.cursor.row))) {
      col += 1;
    }
    await this.addChars(this.cursor.row, col, chars);
  }

  public async delChars(row: Row, col: Col, nchars: number, options: DelCharsOptions = {}) {
    const n = await this.document.getLength(row);
    let deleted: Chars = [];
    if (col < 0) { col = n + col; }
    if ((n > 0) && (nchars > 0) && (col < n)) {
      const mutation = new mutations.DelChars(row, col, nchars);
      await this.do(mutation);
      deleted = mutation.deletedChars;
      if (options.yank) {
        this.register.saveChars(deleted);
      }
    }
    return deleted;
  }

  public async delCharsBeforeCursor(nchars: number, options: DelCharsOptions = {}) {
    nchars = Math.min(this.cursor.col, nchars);
    return await this.delChars(this.cursor.path.row, this.cursor.col - nchars, nchars, options);
  }

  public async delCharsAfterCursor(nchars: number, options: DelCharsOptions = {}) {
    return await this.delChars(this.cursor.path.row, this.cursor.col, nchars, options);
  }

  private async changeChars(row: Row, col: Col, nchars: number, change_fn: (chars: Chars) => Chars) {
    const mutation = new mutations.ChangeChars(row, col, nchars, change_fn);
    await this.do(mutation);
    return mutation.ncharsDeleted;
  }

  public async swapCaseAtCursor() {
    await this.changeChars(this.cursor.row, this.cursor.col, 1, Session.swapCase);
    await this.cursor.right();
  }

  public async swapCaseInVisual(cursor1: Cursor, cursor2: Cursor) {
    if (!(cursor2.path.is(cursor1.path))) {
      logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }

    const nchars = cursor2.col - cursor1.col + 1;
    await this.changeChars(cursor1.row, cursor1.col, nchars, Session.swapCase);
    await this.cursor.from(cursor1);
  }

  public async swapCaseInVisualLine(rows: Array<Row>) {
    await Promise.all(rows.map(async row => await this.changeChars(
      row,
      0,
      await this.document.getLength(row),
      Session.swapCase
    )));
  }

  public async replaceCharsAfterCursor(char: string, nchars: number) {
    const ndeleted = await this.changeChars(this.cursor.row, this.cursor.col, nchars, (chars =>
      chars.map(function(_chr) { return char; })
    ));
    await this.cursor.setCol(this.cursor.col + ndeleted - 1);
  }

  public async clearRowAtCursor(options: {yank?: boolean}) {
    if (options.yank) {
      // yank as a row, not chars
      await this.yankRowAtCursor();
    }
    return await this.delChars(this.cursor.path.row, 0, await this.curLineLength());
  }

  public async yankChars(path: Path, col: Col, nchars: number) {
    const line = await this.document.getLine(path.row);
    if (line.length > 0) {
      this.emit('yank', line.join('').slice(col, col + nchars));
      this.register.saveChars(line.slice(col, col + nchars));
    }
  }

  // options:
  //   - includeEnd says whether to also delete cursor2 location
  public async yankBetween(cursor1: Cursor, cursor2: Cursor, options: {includeEnd?: boolean} = {}) {
    if (!cursor2.path.is(cursor1.path)) {
      logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }

    const offset = options.includeEnd ? 1 : 0;
    await this.yankChars(cursor1.path, cursor1.col, cursor2.col - cursor1.col + offset);
  }

  public async yankRowAtCursor() {
    const serialized_row = await this.document.serializeRow(this.cursor.row);
    this.emit('yank', serialized_row.text);
    return this.register.saveSerializedRows([serialized_row]);
  }

  // options:
  //   - includeEnd says whether to also delete cursor2 location
  public async deleteBetween(cursor1: Cursor, cursor2: Cursor, options: {includeEnd?: boolean, yank?: boolean} = {}) {
    if (!cursor2.path.is(cursor1.path)) {
      logger.warn('Not yet implemented');
      return;
    }

    if (cursor2.col < cursor1.col) {
      [cursor1, cursor2] = [cursor2, cursor1];
    }
    const offset = options.includeEnd ? 1 : 0;
    await this.delChars(cursor1.path.row, cursor1.col, cursor2.col - cursor1.col + offset, options);
  }

  public async newLineBelow(
    options: {setCursor?: string, cursorOptions?: CursorOptions} = {}
  ) {
    options.setCursor = 'first';

    const [ collapsed, hasChildren ] = await Promise.all([
      this.document.collapsed(this.cursor.row),
      this.document.hasChildren(this.cursor.row),
    ]);

    if (this.cursor.path.is(this.viewRoot)) {
      if (!hasChildren) {
        if (!collapsed) {
          await this.toggleBlockCollapsed(this.cursor.row);
        }
      }

      await this.addBlocks(this.cursor.path, 0, [''], options);
    } else if ((!collapsed) && hasChildren) {
      await this.addBlocks(this.cursor.path, 0, [''], options);
    } else {
      const parent = this.cursor.path.parent;
      if (parent == null) {
        throw new Error('Cursor was at viewroot?');
      }
      const index = await this.document.indexInParent(this.cursor.path);
      await this.addBlocks(parent, index + 1, [''], options);
    }
  }

  public async newLineAbove() {
    if (this.cursor.path.is(this.viewRoot)) {
      return;
    }
    const parent = this.cursor.path.parent;
    if (parent == null) {
      throw new Error('Cursor was at viewroot?');
    }
    const index = await this.document.indexInParent(this.cursor.path);
    await this.addBlocks(parent, index, [''], {setCursor: 'first'});
  }

  // behavior of "enter", splitting a line
  // If enter is not at the end:
  //     insert a new node before with the first half of the content
  //     note that this will always preserve child-parent relationships
  // If enter is at the end:
  //     insert a new node after
  //     if the node has children, this is the new first child
  public async newLineAtCursor() {
    if (this.cursor.col === (await this.document.getLength(this.cursor.row))) {
      await this.newLineBelow({cursorOptions: {}});
    } else {
      const mutation = new mutations.DelChars(this.cursor.row, 0, this.cursor.col);
      await this.do(mutation);
      const path = this.cursor.path;

      await this.newLineAbove();
      // cursor now is at inserted path, add the characters
      await this.addCharsAfterCursor(mutation.deletedChars);
      // restore cursor
      await this.cursor.setPosition(path, 0, {});
    }
  }

  // can only join if either:
  // - first is previous sibling of second, AND has no children
  // - second is first child of first, AND has no children
  // returns whether a join successfully happened
  private async _joinRows(first: Path, second: Path, options: {delimiter?: string} = {}) {
    if (first.parent == null) {
      throw new Error('Tried to join first as root?');
    }
    if (second.parent == null) {
      throw new Error('Tried to join first as root?');
    }
    let addDelimiter: string | null = null;
    const firstLine = await this.document.getLine(first.row);
    const secondLine = await this.document.getLine(second.row);
    if (options.delimiter) {
      if (firstLine.length && secondLine.length) {
        if (firstLine[firstLine.length - 1] !== options.delimiter) {
          if (secondLine[0] !== options.delimiter) {
            addDelimiter = options.delimiter;
          }
        }
      }
    }

    if (!await this.document.hasChildren(second.row)) {
      await this.cursor.setPosition(first, -1);
      await this.delBlock(second, { noNew: true, noSave: true });
      if (addDelimiter != null) {
        await this.do(new mutations.AddChars(
          first.row, firstLine.length, [addDelimiter]));
      }
      await this.do(new mutations.AddChars(
        first.row, firstLine.length + (addDelimiter == null ? 0 : 1), secondLine));
      await this.cursor.setPosition(first, firstLine.length);
      return true;
    }

    if (await this.document.hasChildren(first.row)) {
      this.showMessage('Cannot join when both rows have children', {text_class: 'error'});
      return false;
    }

    if (second.parent.row !== first.parent.row) {
      this.showMessage('Cannot join with non sibling/child', {text_class: 'error'});
      return false;
    }

    await this.cursor.setPosition(second, 0);
    await this.delBlock(first, {noNew: true, noSave: true});
    if (addDelimiter != null) {
      await this.do(new mutations.AddChars(second.row, 0, [addDelimiter]));
    }
    await this.do(new mutations.AddChars(second.row, 0, firstLine));

    if (addDelimiter != null) {
      await this.cursor.left();
    }

    return true;
  }

  public async joinAtCursor() {
    const path = this.cursor.path;
    const sib = await this.nextVisible(path);
    if (sib === null) { return false; }
    return await this._joinRows(path, sib, {delimiter: ' '});
  }

  // implements proper "backspace" behavior
  public async deleteAtCursor() {
    if (this.cursor.col > 0) {
      await this.delCharsBeforeCursor(1);
      return true;
    }

    const path = this.cursor.path;
    const sib = await this.prevVisible(path);
    if (sib === null) {
      return false;
    }

    if (await this._joinRows(sib, path)) {
      return true;
    }

    return false;
  }

  private async delBlock(path: Path, options: DelBlockOptions) {
    if (path.parent == null) {
      throw new Error('Cannot delete root');
    }
    return await this.delBlocks(path.parent.row, await this.document.indexInParent(path), 1, options);
  }

  public async delBlocks(
    parent: Row, index: number, nrows: number,
    options: DelBlockOptions = {}
  ) {
    const mutation = new mutations.DetachBlocks(parent, index, nrows, options);
    await this.do(mutation);
    if (!options.noSave) {
      this.register.saveClonedRows(mutation.deleted);
    }
    if (!(await this.isVisible(this.cursor.path))) {
      // view root got deleted
      await this.zoomOut();
    }
  }

  public async delBlocksAtCursor(nrows: number, options = {}) {
    const parent = this.cursor.path.parent;
    if (parent == null) {
      throw new Error('Cursor was at root?');
    }
    const index = await this.document.indexInParent(this.cursor.path);
    return await this.delBlocks(parent.row, index, nrows, options);
  }

  public async addBlocks(
    parent: Path, index = -1, serialized_rows: Array<SerializedBlock>,
    options: {cursorOptions?: CursorOptions, setCursor?: string} = {}
  ) {
    const mutation = new mutations.AddBlocks(parent, index, serialized_rows);
    await this.do(mutation);
    if (options.setCursor === 'first') {
      await this.cursor.setPosition(mutation.added_rows[0], 0, options.cursorOptions);
    } else if (options.setCursor === 'last') {
      await this.cursor.setPosition(mutation.added_rows[mutation.added_rows.length - 1], 0, options.cursorOptions);
    }
  }

  public async yankBlocks(path: Path, nrows: number) {
    const siblings = await this.document.getSiblingRange(path, 0, nrows - 1);
    const serialized = await Promise.all(siblings.map(
      async (x) => await this.document.serialize(x.row)
    ));
    if (this.clientStore.getClientSetting('copyToClipboard')) {
      const clip: string[] = [];
      // depth, collapsed, path
      const ls: [number, boolean, Path][] = [];
      let hasDepth = false;
      const recurse: (p: [number, Path]) => void = async (p: [number, Path]) => {
        const collapsed = (await this.document.getInfo(p[1].row)).collapsed;
        ls.push([p[0], collapsed, p[1]]);
        if (collapsed) {
          return;
        }
        const children = await this.document.getChildren(p[1]);
        for (let k = 0; k < children.length; k++) {
          hasDepth = true;
          await recurse([p[0] + 1, children[k]]);
        }
      };
      for (let k = 0; k < siblings.length; k++) {
        await recurse([0, siblings[k]]);
      }
      if (!this.clientStore.getClientSetting('formattedCopy')) {
        hasDepth = false;
      }
      for (let k = 0; k < ls.length; k++) {
        const p: [number, boolean, Path] = ls[k];
        if (hasDepth) {
          clip.push(' '.repeat(p[0] * 4) + (p[1] ? '+ ' : '- ') + (await this.document.serializeRow(p[2].row)).text);
        } else {
          clip.push((await this.document.serializeRow(p[2].row)).text);
        }
      }
      this.emit('yank', clip.join('\n'));
    }
    this.register.saveSerializedRows(serialized);
  }

  public async yankBlocksAtCursor(nrows: number) {
    await this.yankBlocks(this.cursor.path, nrows);
  }

  public async yankBlocksClone(path: Path, nrows: number) {
    const siblings = await this.document.getSiblingRange(path, 0, nrows - 1);
    this.register.saveClonedRows(siblings.map(sibling => sibling.row));
  }

  public async yankBlocksCloneAtCursor(nrows: number) {
    await this.yankBlocksClone(this.cursor.path, nrows);
  }

  public async attachBlocks(
    parent: Path, ids: Array<Row>, index = -1, options: {setCursor?: string} = {}
  ) {
    const mutation = new mutations.AttachBlocks(parent.row, ids, index);
    const will_work = await mutation.validate(this);
    await this.do(mutation);

    // TODO: do this more elegantly
    if (will_work) {
      if (options.setCursor === 'first') {
        await this.cursor.setPosition(parent.child(ids[0]), 0);
      } else if (options.setCursor === 'last') {
        await this.cursor.setPosition(parent.child(ids[ids.length - 1]), 0);
      }
    }
  }

  private async moveBlock(path: Path, parent_path: Path, index = -1) {
    return await this.do(new mutations.MoveBlock(path, parent_path, index));
  }

  public async indentBlocks(path: Path, numblocks = 1) {
    if (path.is(this.viewRoot)) {
      this.showMessage('Cannot indent view root', {text_class: 'error'});
      return;
    }
    const newparent = await this.document.getSiblingBefore(path);
    if (newparent === null) {
      this.showMessage('Cannot indent without higher sibling', {text_class: 'error'});
      return null;
    }

    if (await this.document.collapsed(newparent.row)) {
      await this.toggleBlockCollapsed(newparent.row);
    }

    const siblings = await this.document.getSiblingRange(path, 0, numblocks - 1);
    for (let i = 0; i < siblings.length; i++) {
      const sib = siblings[i];
      await this.moveBlock(sib, newparent, -1);
    }
    return newparent;
  }

  public async unindentBlocks(path: Path, numblocks = 1) {
    if (path.row === this.viewRoot.row) {
      this.showMessage('Cannot unindent view root', {text_class: 'error'});
      return null;
    }
    if (path.parent == null) {
      throw new Error('Tried to unindent root?');
    }
    const parent = path.parent;
    if (parent.parent == null) {
      this.showMessage('Cannot unindent past root', {text_class: 'error'});
      return;
    }

    const siblings = await this.document.getSiblingRange(path, 0, numblocks - 1);

    const newparent = parent.parent;
    let pp_i = await this.document.indexInParent(parent);

    for (let i = 0; i < siblings.length; i++) {
      const sib = siblings[i];
      pp_i += 1;
      await this.moveBlock(sib, newparent, pp_i);
    }
    if (parent.is(this.viewRoot)) {
      await this.zoomInto(newparent);
    }
    return newparent;
  }

  public async indent(path: Path = this.cursor.path) {
    if (path.is(this.viewRoot)) {
      this.showMessage('Cannot indent view root', {text_class: 'error'});
      return;
    }
    if (await this.document.collapsed(path.row)) {
      await this.indentBlocks(path);
      return ;
    }

    const sib = await this.document.getSiblingBefore(path);
    if (sib == null) {
      this.showMessage('Cannot indent without higher sibling', {text_class: 'error'});
      return;
    }

    const newparent = await this.indentBlocks(path);
    if (newparent === null) { return; }

    const children = await this.document.getChildren(path);
    for (let i = 0; i < children.length; i++) {
      const child = children[i];
      await this.moveBlock(child, sib, -1);
    }
  }

  public async unindent(path: Path = this.cursor.path) {
    if (path.is(this.viewRoot)) {
      this.showMessage('Cannot unindent view root', {text_class: 'error'});
      return;
    }

    const parent = path.parent;
    if (parent == null) {
      throw new Error('Path was at root and yet not viewRoot?');
    }

    if (await this.document.collapsed(path.row)) {
      await this.unindentBlocks(path);
      return;
    }

    if (await this.document.hasChildren(path.row)) {
      this.showMessage('Cannot unindent line with children', {text_class: 'error'});
      return;
    }

    const p_i = await this.document.indexInParent(path);

    const newparent = await this.unindentBlocks(path);
    if (newparent === null) { return; }

    const later_siblings = (await this.document.getChildren(parent)).slice(p_i);
    for (let i = 0; i < later_siblings.length; i++) {
      const sib = later_siblings[i];
      await this.moveBlock(sib, path, -1);
    }
  }

  public async swapDown(path: Path = this.cursor.path) {
    const next = await this.nextVisible(await this.lastVisible(path));
    if (next === null) { return; }
    if (next.parent == null) {
      throw new Error('Next visible should never return root');
    }

    if ((await this.document.hasChildren(next.row)) && (!await this.document.collapsed(next.row))) {
      // make it the first child
      return await this.moveBlock(path, next, 0);
    } else {
      // make it the next sibling
      const parent = next.parent;
      const p_i = await this.document.indexInParent(next);
      return await this.moveBlock(path, parent, p_i + 1);
    }
  }

  public async swapUp(path = this.cursor.path) {
    const prev = await this.prevVisible(path);
    if (prev === null) { return; }
    if (prev.parent == null) {
      throw new Error('Prev visible should never return root');
    }
    if (prev.is(this.viewRoot)) { return; }

    // make it the previous sibling
    const parent = prev.parent;
    const p_i = await this.document.indexInParent(prev);
    await this.moveBlock(path, parent, p_i);
  }

  public async toggleCurBlockCollapsed() {
    await this.toggleBlockCollapsed(this.cursor.row);
  }

  public async toggleBlockCollapsed(row: Row) {
    await this.do(new mutations.ToggleBlock(row));
  }

  public async setCurBlockCollapsed(collapsed: boolean) {
    await this.setBlockCollapsed(this.cursor.row, collapsed);
  }

  public async setBlockCollapsed(row: Row, collapsed: boolean) {
    if ((await this.document.collapsed(row)) !== collapsed) {
      await this.do(new mutations.ToggleBlock(row));
    }
  }

  public async pasteBefore() {
    return await this.register.paste({before: true});
  }

  public async pasteAfter() {
    return await this.register.paste({});
  }

  public get anchor(): Cursor {
    if ((this.mode !== 'VISUAL_LINE') && (this.mode !== 'VISUAL')) {
      throw new Error('Wanted visual line selections but not in visual or visual line mode');
    }
    if (this._anchor == null) {
      throw new Error(`No anchor found in ${this.mode} mode!`);
    }
    return this._anchor;
  }

  public startAnchor() {
    this._anchor = this.cursor.clone();
  }

  public stopAnchor() {
    this._anchor = null;
  }

  // given an anchor and cursor, figures out the right blocks to be deleting
  // returns a parent, minindex, and maxindex
  public async getVisualLineSelections(): Promise<[Path, number, number]> {
    const anchor = this.anchor;
    const cursor = this.cursor;
    const [common, ancestors1, ancestors2] =
      await this.document.getCommonAncestor(cursor.path, anchor.path);
    if (ancestors1.length === 0) {
      if (common.parent == null) {
        throw new Error('Invalid state: cursor was at root?');
      }
      // anchor is underneath cursor
      const parent = common.parent;
      const index = await this.document.indexInParent(cursor.path);
      return [parent, index, index];
    } else if (ancestors2.length === 0) {
      if (common.parent == null) {
        throw new Error('Invalid state: anchor was at root?');
      }
      // cursor is underneath anchor
      const parent = common.parent;
      const index = await this.document.indexInParent(anchor.path);
      return [parent, index, index];
    } else {
      let index1 = await this.document.indexInParent(ancestors1[0] || cursor.path);
      let index2 = await this.document.indexInParent(ancestors2[0] || anchor.path);
      if (index2 < index1) {
        [index1, index2] = [index2, index1];
      }
      return [common, index1, index2];
    }
  }

  public async scroll(npages: number) {
    let numlines = Math.round(npages * this.getLinesPerPage());
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

    this.emit('scroll', numlines);
  }
}

export class InMemorySession extends Session {
  constructor(options: SessionOptions = {}) {
    const doc = new InMemoryDocument();
    doc.loadEmpty(); // NOTE: should be async but is okay since in-memory
    super(
      new ClientStore(new SynchronousInMemory()), doc, options
    );
  }
}

