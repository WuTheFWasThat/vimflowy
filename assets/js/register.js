/*
Represents a yank register.  Holds saved data of one of several types -
either nothing, a set of characters, a set of row ids, or a set of serialized rows
Implements pasting for each of the types
*/


const TYPES = {
  NONE: 0,
  CHARS: 1,
  SERIALIZED_ROWS: 2,
  CLONED_ROWS: 3
};

class Register {

  constructor(session) {
    this.session = session;
    this.saveNone();
    return this;
  }

  saveNone() {
    this.type = TYPES.NONE;
    return this.saved = null;
  }

  saveChars(save) {
    this.type = TYPES.CHARS;
    return this.saved = save;
  }

  saveSerializedRows(save) {
    this.type = TYPES.SERIALIZED_ROWS;
    return this.saved = save;
  }

  saveClonedRows(save) {
    this.type = TYPES.CLONED_ROWS;
    return this.saved = save;
  }

  serialize() {
    return {type: this.type, saved: this.saved};
  }

  deserialize(serialized) {
    this.type = serialized.type;
    return this.saved = serialized.saved;
  }

  //##########
  // Pasting
  //##########

  paste(options = {}) {
    if (this.type === TYPES.CHARS) {
      return this.pasteChars(options);
    } else if (this.type === TYPES.SERIALIZED_ROWS) {
      return this.pasteSerializedRows(options);
    } else if (this.type === TYPES.CLONED_ROWS) {
      return this.pasteClonedRows(options);
    }
  }

  pasteChars(options = {}) {
    let chars = this.saved;
    if (options.before) {
      return this.session.addCharsAtCursor(chars);
    } else {
      this.session.addCharsAfterCursor(chars);
      return this.session.cursor.setCol(this.session.cursor.col + chars.length);
    }
  }

  pasteSerializedRows(options = {}) {
    let { path } = this.session.cursor;
    let { parent } = path;
    let index = this.session.document.indexOf(path);

    let serialized_rows = this.saved;

    if (options.before) {
      return this.session.addBlocks(parent, index, serialized_rows, {setCursor: 'first'});
    } else {
      let children = this.session.document.getChildren(path);
      if ((!this.session.document.collapsed(path.row)) && (children.length > 0)) {
        return this.session.addBlocks(path, 0, serialized_rows, {setCursor: 'first'});
      } else {
        return this.session.addBlocks(parent, (index + 1), serialized_rows, {setCursor: 'first'});
      }
    }
  }

  pasteClonedRows(options = {}) {
    let { path } = this.session.cursor;
    let { parent } = path;
    let index = this.session.document.indexOf(path);

    let cloned_rows = this.saved;

    if (options.before) {
      return this.session.attachBlocks(parent, cloned_rows, index, {setCursor: 'first'});
    } else {
      let children = this.session.document.getChildren(path);
      if ((!this.session.document.collapsed(path.row)) && (children.length > 0)) {
        return this.session.attachBlocks(path, cloned_rows, 0, {setCursor: 'first'});
      } else {
        return this.session.attachBlocks(parent, cloned_rows, (index + 1), {setCursor: 'first'});
      }
    }
  }
}

Register.TYPES = TYPES;

// exports
export default Register;
