/*
Represents a yank register.  Holds saved data of one of several types -
either nothing, a set of characters, a set of row ids, or a set of serialized rows
Implements pasting for each of the types
*/

let REGISTER_TYPES = {
  NONE: 0,
  CHARS: 1,
  SERIALIZED_ROWS: 2,
  CLONED_ROWS: 3
};

// Register is a union type. @saved holds one of several kinds of values
// They can be referenced as @chars, @rows etc.
for (let type in REGISTER_TYPES) {
  Object.defineProperty(this.prototype, type.toLowerCase(), {
    get() { return this.saved; },
    set(save) { return this.saved = save; }
  }
  );
}

class Register {

  constructor(session) {
    this.session = session;
    this.saveNone();
    return this;
  }

  saveNone() {
    this.type = REGISTER_TYPES.NONE;
    return this.saved = null;
  }

  saveChars(save) {
    this.type = REGISTER_TYPES.CHARS;
    return this.saved = save;
  }

  saveSerializedRows(save) {
    this.type = REGISTER_TYPES.SERIALIZED_ROWS;
    return this.saved = save;
  }

  saveClonedRows(save) {
    this.type = REGISTER_TYPES.CLONED_ROWS;
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
    if (this.type === REGISTER_TYPES.CHARS) {
      return this.pasteChars(options);
    } else if (this.type === REGISTER_TYPES.SERIALIZED_ROWS) {
      return this.pasteSerializedRows(options);
    } else if (this.type === REGISTER_TYPES.CLONED_ROWS) {
      return this.pasteClonedRows(options);
    }
  }

  pasteChars(options = {}) {
    if (options.before) {
      return this.session.addCharsAtCursor(this.chars);
    } else {
      this.session.addCharsAfterCursor(this.chars);
      return this.session.cursor.setCol(this.session.cursor.col + this.chars.length);
    }
  }

  pasteSerializedRows(options = {}) {
    let { path } = this.session.cursor;
    let { parent } = path;
    let index = this.session.document.indexOf(path);

    if (options.before) {
      return this.session.addBlocks(parent, index, this.serialized_rows, {setCursor: 'first'});
    } else {
      let children = this.session.document.getChildren(path);
      if ((!this.session.document.collapsed(path.row)) && (children.length > 0)) {
        return this.session.addBlocks(path, 0, this.serialized_rows, {setCursor: 'first'});
      } else {
        return this.session.addBlocks(parent, (index + 1), this.serialized_rows, {setCursor: 'first'});
      }
    }
  }

  pasteClonedRows(options = {}) {
    let { path } = this.session.cursor;
    let { parent } = path;
    let index = this.session.document.indexOf(path);

    if (options.before) {
      return this.session.attachBlocks(parent, this.cloned_rows, index, {setCursor: 'first'});
    } else {
      let children = this.session.document.getChildren(path);
      if ((!this.session.document.collapsed(path.row)) && (children.length > 0)) {
        return this.session.attachBlocks(path, this.cloned_rows, 0, {setCursor: 'first'});
      } else {
        return this.session.attachBlocks(parent, this.cloned_rows, (index + 1), {setCursor: 'first'});
      }
    }
  }
}

// exports
export default Register;
