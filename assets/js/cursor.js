import * as utils from './utils';
import * as constants from './constants';
import EventEmitter from './eventEmitter';

const wordRegex = /^[a-z0-9_]+$/i;

// TODO: make a view class which includes viewRoot and cursor
/*
Cursor represents a cursor within a session
it handles movement logic, insert mode line properties (e.g. bold/italic)
*/
export default class Cursor extends EventEmitter {
  constructor(session, path, col = 0, moveCol = null) {
    super();
    this.session = session;
    this.document = session.document;
    this.path = path;
    this.col = col;
    this.properties = {};
    this._getPropertiesFromContext();

    // -1 means last col
    this.moveCol = moveCol !== null ? moveCol : col;
  }

  get row() {
    return this.path.row;
  }

  clone() {
    // paths are immutable so this is okay
    return new Cursor(this.session, this.path, this.col, this.moveCol);
  }

  _setPath(path) {
    this.emit('rowChange', this.path, path);
    return this.path = path;
  }

  _setCol(col) {
    this.emit('colChange', this.col, col);
    return this.col = col;
  }

  from(other) {
    this._setPath(other.path);
    this._setCol(other.col);
    return this.moveCol = other.moveCol;
  }

  // cursorOptions:
  //   - pastEnd:         means whether we're on the column or past it.
  //                      generally true when in insert mode but not in normal mode
  //                      effectively decides whether we can go past last column or not
  //   - pastEndWord:     whether we consider the end of a word to be after the last letter
  //                      is true in normal mode (for de), false in visual (for vex)
  //   - keepProperties:  for movement, whether we should keep italic/bold state

  setPosition(path, col, cursorOptions) {
    this._setPath(path);
    return this.setCol(col, cursorOptions);
  }

  async setPath(path, cursorOptions) {
    this._setPath(path);
    return this._fromMoveCol(cursorOptions);
  }

  setCol(moveCol, cursorOptions = {pastEnd: true}) {
    this.moveCol = moveCol;
    this._fromMoveCol(cursorOptions);
    // if moveCol was too far, fix it
    // NOTE: this should happen for setting column, but not path
    if (this.moveCol >= 0) {
      return this.moveCol = this.col;
    }
  }

  _fromMoveCol(cursorOptions = {}) {
    const len = this.document.getLength(this.path.row);
    const maxcol = len - (cursorOptions.pastEnd ? 0 : 1);
    let col;
    if (this.moveCol < 0) {
      col = Math.max(0, len + this.moveCol + 1);
    } else {
      col = Math.max(0, Math.min(maxcol, this.moveCol));
    }
    this._setCol(col);
    if (!cursorOptions.keepProperties) {
      return this._getPropertiesFromContext();
    }
  }

  _left() {
    return this.setCol(this.col - 1);
  }

  _right() {
    return this.setCol(this.col + 1);
  }

  async left() {
    if (this.col > 0) {
      return this._left();
    }
  }

  async right(cursorOptions = {}) {
    const shift = cursorOptions.pastEnd ? 0 : 1;
    if (this.col < this.document.getLength(this.path.row) - shift) {
      return this._right();
    }
  }

  async backIfNeeded() {
    if (this.col > this.document.getLength(this.path.row) - 1) {
      await this.left();
      return true;
    }
    return false;
  }

  async atVisibleEnd() {
    if (this.col < this.document.getLength(this.path.row) - 1) {
      return false;
    } else {
      const nextpath = this.session.nextVisible(this.path);
      if (nextpath !== null) {
        return false;
      }
    }
    return true;
  }

  async _nextChar() {
    if (this.col < this.document.getLength(this.path.row) - 1) {
      this._right();
      return true;
    } else {
      const nextpath = this.session.nextVisible(this.path);
      if (nextpath !== null) {
        this.setPosition(nextpath, 0);
        return true;
      }
    }
    return false;
  }

  async atVisibleStart() {
    if (this.col > 0) {
      return false;
    } else {
      const prevpath = this.session.prevVisible(this.path);
      if (prevpath !== null) {
        return false;
      }
    }
    return true;
  }

  async _prevChar() {
    if (this.col > 0) {
      this._left();
      return true;
    } else {
      const prevpath = this.session.prevVisible(this.path);
      if (prevpath !== null) {
        this.setPosition(prevpath, -1);
        return true;
      }
    }
    return false;
  }

  async home() {
    this.setCol(0);
    return this;
  }

  async end(cursorOptions = {cursor: {}}) {
    this.setCol(cursorOptions.pastEnd ? -1 : -2);
    return this;
  }

  async visibleHome() {
    let path;
    if (this.session.viewRoot.is(this.session.document.root)) {
      path = this.session.nextVisible(this.session.viewRoot);
    } else {
      path = this.session.viewRoot;
    }
    this.setPosition(path, 0);
    return this;
  }

  async visibleEnd() {
    const path = this.session.lastVisible();
    this.setPosition(path, 0);
    return this;
  }

  async isInWhitespace(path, col) {
    const char = this.document.getChar(path.row, col);
    return utils.isWhitespace(char);
  }

  async isInWord(path, col, matchChar) {
    if (utils.isWhitespace(matchChar)) {
      return false;
    }

    const char = this.document.getChar(path.row, col);
    if (utils.isWhitespace(char)) {
      return false;
    }

    if (wordRegex.test(char)) {
      return wordRegex.test(matchChar);
    } else {
      return !(wordRegex.test(matchChar));
    }
  }

  // return function that sees whether we're still in the word
  _getWordCheck(options, matchChar) {
    if (options.whitespaceWord) {
      return async (path, col) => !await this.isInWhitespace(path, col);
    } else {
      return async (path, col) => await this.isInWord(path, col, matchChar);
    }
  }

  async beginningWord(options = {}) {
    if (await this.atVisibleStart()) {
      return this;
    }
    await this._prevChar();
    while ((!await this.atVisibleStart()) &&
           await this.isInWhitespace(this.path, this.col)) {
      await this._prevChar();
    }

    const wordcheck = this._getWordCheck(options, this.document.getChar(this.path.row, this.col));
    while ((this.col > 0) && (await wordcheck(this.path, this.col-1))) {
      this._left();
    }
    return this;
  }

  async endWord(options = {}) {
    if (await this.atVisibleEnd()) {
      if (options.cursor.pastEnd) {
        this._right();
      }
      return this;
    }

    await this._nextChar();
    while ((! await this.atVisibleEnd()) &&
            await this.isInWhitespace(this.path, this.col)) {
      await this._nextChar();
    }

    let end = this.document.getLength(this.path.row) - 1;
    const wordcheck = this._getWordCheck(options, this.document.getChar(this.path.row, this.col));
    while (this.col < end && (await wordcheck(this.path, this.col+1))) {
      this._right();
    }

    if (options.cursor.pastEndWord) {
      this._right();
    }

    end = (this.document.getLength(this.path.row)) - 1;
    if (this.col === end && options.cursor.pastEnd) {
      this._right();
    }
    return this;
  }

  async nextWord(options = {}) {
    if (await this.atVisibleEnd()) {
      if (options.cursor.pastEnd) {
        this._right();
      }
      return this;
    }

    let end = this.document.getLength(this.path.row) - 1;
    const wordcheck = this._getWordCheck(options, this.document.getChar(this.path.row, this.col));
    while (this.col < end && (await wordcheck(this.path, this.col+1))) {
      this._right();
    }

    await this._nextChar();
    while ((!await this.atVisibleEnd()) &&
            await this.isInWhitespace(this.path, this.col)) {
      await this._nextChar();
    }

    end = (this.document.getLength(this.path.row)) - 1;
    if (this.col === end && options.cursor.pastEnd) {
      this._right();
    }
    return this;
  }

  async findNextChar(char, options = {}) {
    const end = this.document.getLength(this.path.row) - 1;
    if (this.col === end) {
      return;
    }

    let col = this.col;
    if (options.beforeFound) {
      col += 1;
    }

    let found = null;
    while (col < end) {
      col += 1;
      if (this.document.getChar(this.path.row, col) === char) {
        found = col;
        break;
      }
    }

    if (found === null) {
      return;
    }

    this.setCol(found);
    if (options.cursor.pastEnd) {
      this._right();
    }
    if (options.beforeFound) {
      return this._left();
    }
  }

  async findPrevChar(char, options = {}) {
    if (this.col === 0) {
      return;
    }

    let col = this.col;
    if (options.beforeFound) {
      col -= 1;
    }

    let found = null;
    while (col > 0) {
      col -= 1;
      if (this.document.getChar(this.path.row, col) === char) {
        found = col;
        break;
      }
    }

    if (found === null) {
      return;
    }

    this.setCol(found);
    if (options.beforeFound) {
      return this._right();
    }
  }

  async up(cursorOptions = {}) {
    const path = this.session.prevVisible(this.path);
    if (path !== null) {
      return await this.setPath(path, cursorOptions);
    }
  }

  async down(cursorOptions = {}) {
    const path = this.session.nextVisible(this.path);
    if (path !== null) {
      return await this.setPath(path, cursorOptions);
    }
  }

  async parent(cursorOptions = {}) {
    const path = this.path.parent;
    if (path.row === this.document.root.row) {
      return;
    }
    if (this.path.is(this.session.viewRoot)) {
      await this.session.changeViewRoot(path);
    }
    return await this.setPath(path, cursorOptions);
  }

  async prevSibling(cursorOptions = {}) {
    const prevsib = this.document.getSiblingBefore(this.path);
    if (prevsib !== null) {
      return await this.setPath(prevsib, cursorOptions);
    }
  }

  async nextSibling(cursorOptions = {}) {
    const nextsib = this.document.getSiblingAfter(this.path);
    if (nextsib !== null) {
      return await this.setPath(nextsib, cursorOptions);
    }
  }

  // cursor properties

  setProperty(property, value) {
    return this.properties[property] = value;
  }

  getProperty(property) {
    return this.properties[property];
  }

  toggleProperty(property) {
    return this.setProperty(property, !this.getProperty(property));
  }

  // get whether the cursor should be bold/italic based on surroundings
  // NOTE: only relevant for insert mode.
  _getPropertiesFromContext() {
    const line = this.document.getLine(this.path.row);
    let obj;
    if (line.length === 0) {
      obj = {};
    } else if (this.col === 0) {
      obj = line[this.col];
    } else {
      obj = line[this.col-1];
    }
    constants.text_properties.forEach((property) => {
      this.setProperty(property, obj[property]);
    });
  }
}
