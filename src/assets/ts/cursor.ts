import { isWhitespace } from './utils/text';
import EventEmitter from './utils/eventEmitter';
import { Row, Col, CursorOptions } from './types';
import Path from './path';
import Document from './document';
import Session from './session';

const wordRegex = /^[a-z0-9_]+$/i;

// options for word movements, e.g. w/e/b/f/t
type WordMovementOptions = {
  // whether the word should consider all non-whitespace characters
  whitespaceWord?: boolean,
  // whether to stop before the character found
  beforeFound?: boolean,
  cursor?: CursorOptions,
};

// TODO: make a view class which includes viewRoot and cursor
/*
   Cursor represents a cursor within a session
   Handles movement logic
 */
export default class Cursor extends EventEmitter {
  public col: Col;
  public path: Path;
  public session: Session;
  public document: Document;

  private moveCol: Col;

  constructor(
    session: Session, path: Path, col: Col = 0, moveCol: Col | null = null
  ) {
    super();
    this.session = session;
    this.document = session.document;
    this.path = path;
    this.col = col;

    // -1 means last col
    this.moveCol = moveCol !== null ? moveCol : col;
  }

  get row() {
    return this.path.row;
  }

  public clone() {
    // paths are immutable so this is okay
    return new Cursor(this.session, this.path, this.col, this.moveCol);
  }

  public async _setPath(path: Path) {
    await this.emitAsync('rowChange', this.path, path);
    this.session.document.searcher.update(this.path.row);
    this.path = path;
  }

  private async _setCol(col: Col) {
    await this.emitAsync('colChange', this.col, col);
    this.col = col;
  }

  public async from(other: Cursor) {
    await this._setPath(other.path);
    await this._setCol(other.col);
    this.moveCol = other.moveCol;
  }

  public async setPosition(path: Path, col: Col, cursorOptions?: CursorOptions) {
    await this._setPath(path);
    await this.setCol(col, cursorOptions);
  }

  public async setPath(path: Path, cursorOptions?: CursorOptions) {
    await this._setPath(path);
    await this._fromMoveCol(cursorOptions);
  }

  public async setCol(moveCol: Col, cursorOptions: CursorOptions = { pastEnd: true }) {
    this.moveCol = moveCol;
    await this._fromMoveCol(cursorOptions);
    // if moveCol was too far, fix it
    // NOTE: this should happen for setting column, but not path
    if (this.moveCol >= 0) {
      this.moveCol = this.col;
    }
  }

  private async _fromMoveCol(cursorOptions: CursorOptions = {}) {
    const len = await this.document.getLength(this.path.row);
    const maxcol = len - (cursorOptions.pastEnd ? 0 : 1);
    let col;
    if (this.moveCol < 0) {
      col = Math.max(0, len + this.moveCol + 1);
    } else {
      col = Math.max(0, Math.min(maxcol, this.moveCol));
    }
    await this._setCol(col);
  }

  private async _left() {
    await this.setCol(this.col - 1);
  }

  private async _right() {
    await this.setCol(this.col + 1);
  }

  public async left() {
    if (this.col > 0) {
      await this._left();
    }
  }

  public async right(
    cursorOptions: {pastEnd?: boolean} = {}
  ) {
    const shift = cursorOptions.pastEnd ? 0 : 1;
    if (this.col < (await this.document.getLength(this.path.row)) - shift) {
      await this._right();
    }
  }

  public async backIfNeeded() {
    if (this.col > (await this.document.getLength(this.path.row)) - 1) {
      await this.left();
      return true;
    }
    return false;
  }

  public async atVisibleEnd() {
    if (this.col < (await this.document.getLength(this.path.row)) - 1) {
      return false;
    } else {
      const nextpath = await this.session.nextVisible(this.path);
      if (nextpath !== null) {
        return false;
      }
    }
    return true;
  }

  private async _nextChar() {
    if (this.col < (await this.document.getLength(this.path.row)) - 1) {
      await this._right();
      return true;
    } else {
      const nextpath = await this.session.nextVisible(this.path);
      if (nextpath !== null) {
        await this.setPosition(nextpath, 0);
        return true;
      }
    }
    return false;
  }

  public async atVisibleStart() {
    if (this.col > 0) {
      return false;
    } else {
      const prevpath = await this.session.prevVisible(this.path);
      if (prevpath !== null) {
        return false;
      }
    }
    return true;
  }

  private async _prevChar() {
    if (this.col > 0) {
      await this._left();
      return true;
    } else {
      const prevpath = await this.session.prevVisible(this.path);
      if (prevpath !== null) {
        await this.setPosition(prevpath, -1);
        return true;
      }
    }
    return false;
  }

  public async home() {
    await this.setCol(0);
    return this;
  }

  public async end(cursorOptions: CursorOptions = {}) {
    await this.setCol(cursorOptions.pastEnd ? -1 : -2);
    return this;
  }

  public async visibleHome() {
    let path;
    if (this.session.viewRoot.isRoot()) {
      const firstChild = await this.session.nextVisible(this.session.viewRoot);
      if (firstChild == null) {
        throw new Error('No next visible for root?');
      }
      if (firstChild.parent == null) {
        throw new Error('Next visible of root was root?');
      }
      path = firstChild;
    } else {
      path = this.session.viewRoot;
    }
    await this.setPosition(path, 0);
    return this;
  }

  public async visibleEnd() {
    const path = await this.session.lastVisible();
    await this.setPosition(path, 0);
    return this;
  }

  public async isInWhitespace(path: Path, col: Col) {
    const char = await this.document.getChar(path.row, col);
    return isWhitespace(char);
  }

  public async isInWord(path: Path, col: Col, matchChar: string) {
    if (isWhitespace(matchChar)) {
      return false;
    }

    const char = await this.document.getChar(path.row, col);
    if (isWhitespace(char)) {
      return false;
    }

    if (wordRegex.test(char)) {
      return wordRegex.test(matchChar);
    } else {
      return !(wordRegex.test(matchChar));
    }
  }

  // return function that sees whether we're still in the word
  private _getWordCheck(options: WordMovementOptions, matchChar: string) {
    if (options.whitespaceWord) {
      return async (path: Path, col: Col) => {
        return !(await this.isInWhitespace(path, col));
      };
    } else {
      return async (path: Path, col: Col) => await this.isInWord(path, col, matchChar);
    }
  }

  public async beginningWord(options: WordMovementOptions = {}) {
    if (await this.atVisibleStart()) {
      return this;
    }
    await this._prevChar();
    while ((!(await this.atVisibleStart())) &&
           (await this.isInWhitespace(this.path, this.col))) {
      await this._prevChar();
    }

    const wordcheck = this._getWordCheck(
      options,
      await this.document.getChar(this.path.row, this.col)
    );
    while ((this.col > 0) && (await wordcheck(this.path, this.col - 1))) {
      await this._left();
    }
    return this;
  }

  public async endWord(options: WordMovementOptions = {}) {
    if (await this.atVisibleEnd()) {
      if (options.cursor && options.cursor.pastEnd) {
        await this._right();
      }
      return this;
    }

    await this._nextChar();
    while ((!(await this.atVisibleEnd())) &&
           (await this.isInWhitespace(this.path, this.col))) {
      await this._nextChar();
    }

    let end = (await this.document.getLength(this.path.row)) - 1;
    const wordcheck = this._getWordCheck(
      options,
      await this.document.getChar(this.path.row, this.col)
    );
    while ((this.col < end) && (await wordcheck(this.path, this.col + 1))) {
      await this._right();
    }

    if (options.cursor && options.cursor.pastEndWord) {
      await this._right();
    }

    end = (await this.document.getLength(this.path.row)) - 1;
    if (this.col === end && options.cursor && options.cursor.pastEnd) {
      await this._right();
    }
    return this;
  }

  public async nextWord(options: WordMovementOptions = {}) {
    if (await this.atVisibleEnd()) {
      if (options.cursor && options.cursor.pastEnd) {
        await this._right();
      }
      return this;
    }

    let end = (await this.document.getLength(this.path.row)) - 1;
    const wordcheck = this._getWordCheck(
      options,
      await this.document.getChar(this.path.row, this.col)
    );
    while ((this.col < end) && (await wordcheck(this.path, this.col + 1))) {
      await this._right();
    }
    await this._nextChar();

    let found_next_word = false;
    let found_whitespace = false;
    while (true) {
      if (!await this.isInWhitespace(this.path, this.col)) {
        if (found_whitespace) {
          found_next_word = true;
        }
        break;
      }
      found_whitespace = true;
      if (await this.atVisibleEnd()) {
        break;
      }
      await this._nextChar();
    }

    if (!found_next_word) {
      if (options.cursor && options.cursor.pastEnd) {
        end = (await this.document.getLength(this.path.row)) - 1;
        if (this.col === end) {
          await this._right();
        }
      }
    }
    return this;
  }

  public async findNextChar(char: string, options: WordMovementOptions = {}) {
    const end = (await this.document.getLength(this.path.row)) - 1;
    if (this.col === end) {
      return;
    }

    let col = this.col;
    if (options.beforeFound) {
      col += 1;
    }

    let found: number | null = null;
    while (col < end) {
      col += 1;
      if ((await this.document.getChar(this.path.row, col)) === char) {
        found = col;
        break;
      }
    }

    if (found === null) {
      return;
    }

    await this.setCol(found);
    if (options.cursor && options.cursor.pastEnd) {
      await this._right();
    }
    if (options.beforeFound) {
      return await this._left();
    }
  }

  public async findPrevChar(char: string, options: WordMovementOptions = {}) {
    if (this.col === 0) {
      return;
    }

    let col = this.col;
    if (options.beforeFound) {
      col -= 1;
    }

    let found: number | null  = null;
    while (col > 0) {
      col -= 1;
      if ((await this.document.getChar(this.path.row, col)) === char) {
        found = col;
        break;
      }
    }

    if (found === null) {
      return;
    }

    await this.setCol(found);
    if (options.beforeFound) {
      await this._right();
    }
  }

  public async up(cursorOptions: CursorOptions = {}) {
    const path = await this.session.prevVisible(this.path);
    if (path !== null) {
      await this.setPath(path, cursorOptions);
    }
  }

  public async down(cursorOptions: CursorOptions = {}) {
    const path = await this.session.nextVisible(this.path);
    if (path !== null) {
      await this.setPath(path, cursorOptions);
    }
  }

  public async parent(cursorOptions: CursorOptions = {}) {
    const newpath = this.path.parent;
    if (newpath == null) {
      throw new Error('Cursor was at root');
    }
    if (newpath.parent == null) {
      return;
    }
    if (this.path.is(this.session.viewRoot)) {
      await this.session.changeViewRoot(newpath);
    }
    return await this.setPath(newpath, cursorOptions);
  }

  public async prevSibling(cursorOptions: CursorOptions = {}) {
    const prevsib = await this.document.getSiblingBefore(this.path);
    if (prevsib !== null) {
      return await this.setPath(prevsib, cursorOptions);
    }
  }

  public async nextSibling(cursorOptions: CursorOptions = {}) {
    const nextsib = await this.document.getSiblingAfter(this.path);
    if (nextsib !== null) {
      return await this.setPath(nextsib, cursorOptions);
    }
  }
}

// NOTE: this doesnt go into the document tree since
// 1. it doesnt deduplicate cloned rows
// 2. implementation details, e.g. this isn't immutable
export class CursorsInfoTree {
  public row: Row;

  // actual cursor!
  public cursor: Col | null;
  // has regular selection
  public selected: {[col: number]: boolean};
  // is visually selected (entire row)
  public visual: boolean;

  // has children with selections
  public children: {[row: number]: CursorsInfoTree};
  public parent: CursorsInfoTree | null;
  public hasSelection: boolean;

  constructor(row: Row, parent: null | CursorsInfoTree = null) {
    if (parent === null && (row !== Path.rootRow())) {
      throw new Error('CursorsInfoTree rooted at non-root row');
    }
    this.row = row;
    this.visual = false;
    this.selected = {};
    this.cursor = null;
    this.children = {};
    this.parent = parent;
    this.hasSelection = false;
  }

  public getPath(path: Path): CursorsInfoTree {
    let result = (this as CursorsInfoTree);
    path.getAncestry().forEach((row) => {
      result = result.getChild(row);
    });
    return result;
  }

  public getChild(row: Row): CursorsInfoTree {
    const child = this.children[row];
    if (child != null) {
      return child;
    }
    const newChild =  new CursorsInfoTree(row, this);
    this.children[row] = newChild;
    return newChild;
  }

  private markSelected() {
    if (!this.hasSelection) {
      this.hasSelection = true;
      if (this.parent) {
        this.parent.markSelected();
      }
    }
  }

  public markCols(cols: Array<Col>) {
    cols.forEach((col) => {
      this.selected[col] = true;
    });
    this.markSelected();
  }

  public markCursor(col: Col) {
    this.cursor = col;
    this.markSelected();
  }

  public markVisual() {
    this.visual = true;
    this.markSelected();
  }

  public markChildrenVisual(childRows: Array<Row>) {
    childRows.forEach((row) => {
      const child = this.getChild(row);
      child.markVisual();
    });
  }
}

