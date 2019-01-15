/*
Represents a yank register.  Holds saved data of one of several types -
either nothing, a set of characters, a set of row ids, or a set of serialized rows
Implements pasting for each of the types
*/
import Session from './session';
import { Line, SerializedBlock, Row } from './types';

export enum RegisterTypes {
  NONE = 0,
  CHARS = 1,
  SERIALIZED_ROWS = 2,
  CLONED_ROWS = 3,
}

export type RegisterValue = null | Line | Array<SerializedBlock> | Array<Row>;
export type SerializedRegister = {
  type: RegisterTypes,
  saved: RegisterValue,
};

type PasteOptions = {before?: boolean};

export default class Register {
  private session: Session;
  private type: RegisterTypes = RegisterTypes.NONE;
  private saved: RegisterValue = null;

  constructor(session: Session) {
    this.session = session;
    this.saveNone();
    return this;
  }

  public saveNone() {
    this.type = RegisterTypes.NONE;
    this.saved = null;
  }

  public saveChars(save: Line) {
    this.type = RegisterTypes.CHARS;
    this.saved = save;
    this.session.emit('yank', {type: this.type, saved: this.saved});
  }

  public saveSerializedRows(save: Array<SerializedBlock>) {
    this.type = RegisterTypes.SERIALIZED_ROWS;
    this.saved = save;
    this.session.emit('yank', {type: this.type, saved: this.saved});
  }

  public saveClonedRows(save: Array<Row>) {
    this.type = RegisterTypes.CLONED_ROWS;
    this.saved = save;
    this.session.emit('yank', {type: this.type, saved: this.saved});
  }

  public serialize() {
    return {type: this.type, saved: this.saved};
  }

  public deserialize(serialized: SerializedRegister) {
    this.type = serialized.type;
    this.saved = serialized.saved;
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
    const chars = (this.saved as Line);
    if (options.before) {
      await this.session.addCharsAtCursor(chars);
    } else {
      await this.session.addCharsAfterCursor(chars);
      await this.session.cursor.setCol(this.session.cursor.col + chars.length);
    }
  }

  public async pasteSerializedRows(options: PasteOptions = {}) {
    const path = this.session.cursor.path;
    if (path.parent == null) {
      throw new Error('Cursor was at root');
    }
    const parent = path.parent;
    const index = await this.session.document.indexInParent(path);

    const serialized_rows = (this.saved as Array<SerializedBlock>);

    if (options.before) {
      await this.session.addBlocks(parent, index, serialized_rows, {setCursor: 'first'});
    } else {
      if (path.is(this.session.viewRoot) ||
          ((!await this.session.document.collapsed(path.row)) &&
           (await this.session.document.hasChildren(path.row)))) {
        await this.session.addBlocks(path, 0, serialized_rows, {setCursor: 'first'});
      } else {
        await this.session.addBlocks(parent, index + 1, serialized_rows, {setCursor: 'first'});
      }
    }
  }

  public async pasteClonedRows(options: PasteOptions = {}) {
    const path = this.session.cursor.path;
    if (path.parent == null) {
      throw new Error('Cursor was at root');
    }
    const parent = path.parent;
    const index = await this.session.document.indexInParent(path);

    const cloned_rows = (this.saved as Array<Row>);

    if (options.before) {
      await this.session.attachBlocks(parent, cloned_rows, index, {setCursor: 'first'});
    } else {
      if (path.is(this.session.viewRoot) ||
          ((!await this.session.document.collapsed(path.row)) &&
           (await this.session.document.hasChildren(path.row)))) {
        await this.session.attachBlocks(path, cloned_rows, 0, {setCursor: 'first'});
      } else {
        await this.session.attachBlocks(parent, cloned_rows, index + 1, {setCursor: 'first'});
      }
    }
  }
}
