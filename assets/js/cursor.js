import * as utils from './utils';
import * as constants from './constants';
import EventEmitter from './eventEmitter';

const wordRegex = /^[a-z0-9_]+$/i;

// TODO: make a view class which includes viewRoot and cursor
/*
Cursor represents a cursor within a session
it handles movement logic, insert mode line properties (e.g. bold/italic)
*/
class Cursor extends EventEmitter {
  constructor(session, path = null, col = null, moveCol = null) {
    super();
    this.session = session;
    this.document = session.document;
    this.path = path !== null ? path : (this.document.getChildren(this.session.viewRoot))[0];
    this.col = col !== null ? col : 0;
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

  setPath(path, cursorOptions) {
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

  left() {
    if (this.col > 0) {
      return this._left();
    }
  }

  right(cursorOptions = {}) {
    const shift = cursorOptions.pastEnd ? 0 : 1;
    if (this.col < (this.document.getLength(this.path.row)) - shift) {
      return this._right();
    }
  }

  backIfNeeded() {
    if (this.col > (this.document.getLength(this.path.row)) - 1) {
      return this.left();
    }
  }

  atVisibleEnd() {
    if (this.col < (this.document.getLength(this.path.row)) - 1) {
      return false;
    } else {
      const nextpath = this.session.nextVisible(this.path);
      if (nextpath !== null) {
        return false;
      }
    }
    return true;
  }

  nextChar() {
    if (this.col < (this.document.getLength(this.path.row)) - 1) {
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

  atVisibleStart() {
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

  prevChar() {
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

  home() {
    this.setCol(0);
    return this;
  }

  end(cursorOptions = {cursor: {}}) {
    this.setCol(cursorOptions.pastEnd ? -1 : -2);
    return this;
  }

  visibleHome() {
    let path;
    if (this.session.viewRoot.is(this.session.document.root)) {
      path = this.session.nextVisible(this.session.viewRoot);
    } else {
      path = this.session.viewRoot;
    }
    this.setPosition(path, 0);
    return this;
  }

  visibleEnd() {
    const path = this.session.lastVisible();
    this.setPosition(path, 0);
    return this;
  }

  isInWhitespace(path, col) {
    const char = this.document.getChar(path.row, col);
    return utils.isWhitespace(char);
  }

  isInWord(path, col, matchChar) {
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

  getWordCheck(options, matchChar) {
    if (options.whitespaceWord) {
      return (path, col) => !this.isInWhitespace(path, col);
    } else {
      return (path, col) => this.isInWord(path, col, matchChar);
    }
  }

  beginningWord(options = {}) {
    if (this.atVisibleStart()) {
      return this;
    }
    this.prevChar();
    while ((!this.atVisibleStart()) && this.isInWhitespace(this.path, this.col)) {
      this.prevChar();
    }

    const wordcheck = this.getWordCheck(options, (this.document.getChar(this.path.row, this.col)));
    while ((this.col > 0) && wordcheck(this.path, this.col-1)) {
      this._left();
    }
    return this;
  }

  endWord(options = {}) {
    if (this.atVisibleEnd()) {
      if (options.cursor.pastEnd) {
        this._right();
      }
      return this;
    }

    this.nextChar();
    while ((!this.atVisibleEnd()) && this.isInWhitespace(this.path, this.col)) {
      this.nextChar();
    }

    let end = this.document.getLength(this.path.row) - 1;
    const wordcheck = this.getWordCheck(options, this.document.getChar(this.path.row, this.col));
    while (this.col < end && wordcheck(this.path, (this.col+1))) {
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

  nextWord(options = {}) {
    if (this.atVisibleEnd()) {
      if (options.cursor.pastEnd) {
        this._right();
      }
      return this;
    }

    let end = this.document.getLength(this.path.row) - 1;
    const wordcheck = this.getWordCheck(options, this.document.getChar(this.path.row, this.col));
    while (this.col < end && wordcheck(this.path, this.col+1)) {
      this._right();
    }

    this.nextChar();
    while ((!this.atVisibleEnd()) && this.isInWhitespace(this.path, this.col)) {
      this.nextChar();
    }

    end = (this.document.getLength(this.path.row)) - 1;
    if (this.col === end && options.cursor.pastEnd) {
      this._right();
    }
    return this;
  }

  findNextChar(char, options = {}) {
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

  findPrevChar(char, options = {}) {
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

  up(cursorOptions = {}) {
    const path = this.session.prevVisible(this.path);
    if (path !== null) {
      return this.setPath(path, cursorOptions);
    }
  }

  down(cursorOptions = {}) {
    const path = this.session.nextVisible(this.path);
    if (path !== null) {
      return this.setPath(path, cursorOptions);
    }
  }

  parent(cursorOptions = {}) {
    const path = this.path.parent;
    if (path.row === this.document.root.row) {
      return;
    }
    if (this.path.is(this.session.viewRoot)) {
      this.session._changeViewRoot(path);
    }
    return this.setPath(path, cursorOptions);
  }

  prevSibling(cursorOptions = {}) {
    const prevsib = this.document.getSiblingBefore(this.path);
    if (prevsib !== null) {
      return this.setPath(prevsib, cursorOptions);
    }
  }

  nextSibling(cursorOptions = {}) {
    const nextsib = this.document.getSiblingAfter(this.path);
    if (nextsib !== null) {
      return this.setPath(nextsib, cursorOptions);
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

// exports
export default Cursor;
