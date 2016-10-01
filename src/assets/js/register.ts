/*
Represents a yank register.  Holds saved data of one of several types -
either nothing, a set of characters, a set of row ids, or a set of serialized rows
Implements pasting for each of the types
*/
import Session from './session';

export enum RegisterTypes {
  NONE = 0,
  CHARS = 1,
  SERIALIZED_ROWS = 2,
  CLONED_ROWS = 3,
}

type PasteOptions = {before?: boolean};

export default class Register {
  private session: Session;
  private type: RegisterTypes;
  private saved: any; // TODO

  constructor(session) {
    this.session = session;
    this.saveNone();
    return this;
  }

  public saveNone() {
    this.type = RegisterTypes.NONE;
    this.saved = null;
  }

  public saveChars(save) {
    this.type = RegisterTypes.CHARS;
    this.saved = save;
  }

  public saveSerializedRows(save) {
    this.type = RegisterTypes.SERIALIZED_ROWS;
    this.saved = save;
  }

  public saveClonedRows(save) {
    this.type = RegisterTypes.CLONED_ROWS;
    this.saved = save;
  }

  public serialize() {
    return {type: this.type, saved: this.saved};
  }

  public deserialize(serialized) {
    this.type = serialized.type;
    return this.saved = serialized.saved;
  }

  // Pasting

  public async paste(options: PasteOptions = {}) {
    if (this.type === RegisterTypes.CHARS) {
      await this.pasteChars(options);
    } else if (this.type === RegisterTypes.SERIALIZED_ROWS) {
      await this.pasteSerializedRows(options);
    } else if (this.type === RegisterTypes.CLONED_ROWS) {
      await this.pasteClonedRows(options);
    }
  }

  public async pasteChars(options: PasteOptions = {}) {
    const chars = this.saved;
    if (options.before) {
      await this.session.addCharsAtCursor(chars);
    } else {
      await this.session.addCharsAfterCursor(chars);
      await this.session.cursor.setCol(this.session.cursor.col + chars.length);
    }
  }

  public async pasteSerializedRows(options: PasteOptions = {}) {
    const path = this.session.cursor.path;
    const parent = path.parent;
    const index = this.session.document.indexOf(path);

    const serialized_rows = this.saved;

    if (options.before) {
      await this.session.addBlocks(parent, index, serialized_rows, {setCursor: 'first'});
    } else {
      const children = this.session.document.getChildren(path);
      if ((!this.session.document.collapsed(path.row)) && (children.length > 0)) {
        await this.session.addBlocks(path, 0, serialized_rows, {setCursor: 'first'});
      } else {
        await this.session.addBlocks(parent, index + 1, serialized_rows, {setCursor: 'first'});
      }
    }
  }

  public async pasteClonedRows(options: PasteOptions = {}) {
    const path = this.session.cursor.path;
    const parent = path.parent;
    const index = this.session.document.indexOf(path);

    const cloned_rows = this.saved;

    if (options.before) {
      await this.session.attachBlocks(parent, cloned_rows, index, {setCursor: 'first'});
    } else {
      const children = this.session.document.getChildren(path);
      if ((!this.session.document.collapsed(path.row)) && (children.length > 0)) {
        await this.session.attachBlocks(path, cloned_rows, 0, {setCursor: 'first'});
      } else {
        await this.session.attachBlocks(parent, cloned_rows, index + 1, {setCursor: 'first'});
      }
    }
  }
}
