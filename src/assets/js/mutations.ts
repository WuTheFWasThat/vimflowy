/*
mutations mutate a document within a session, and are undoable
each mutation should implement a constructor, as well as the following methods:

    str: () -> string
        prints itself
    async mutate: (session) -> void
        takes a session and acts on it (mutates the session)
    async rewind: (session) -> void
        takes a session, assumed be in the state right after the mutation was applied,
        and returns a list of mutations for undoing it

the mutation may also optionally implement

    async validate: (session) -> bool
        returns whether this action is valid at the time (i.e. whether it is okay to call mutate)
    async remutate: (session) -> void
        takes a session, and acts on it.  assumes that mutate has been called once already
        by default, remutate is the same as mutate.
        it should be implemented only if it is more efficient than the mutate implementation
    async moveCursor: (cursor) -> void
        takes a cursor, and moves it according to how the cursor should move
*/

import * as _ from 'lodash';
import * as errors from './errors';
import Session from './session';
import Cursor from './cursor';
import { AttachedChildInfo } from './document';
import { Row, Col, Char, Chars, SerializedBlock, SerializedPath, Line } from './types';
import Path from './path';

// validate inserting id as a child of parent_id
const validateRowInsertion = async function(
  session: Session, parent_id: number, id: number,
  options: {noSiblingCheck?: boolean} = {}
) {
  // check that there won't be doubled siblings
  if (!options.noSiblingCheck) {
    if (await session.document._hasChild(parent_id, id)) {
      session.showMessage('Cloned rows cannot be inserted as siblings', {text_class: 'error'});
      return false;
    }
  }

  // check that there are no cycles
  // Precondition: tree is not already circular
  // It is sufficient to check if the row is an ancestor of the new parent,
  // because if there was a clone underneath the row which was an ancestor of 'parent',
  // then 'row' would also be an ancestor of 'parent'.
  if (_.includes(await session.document.allAncestors(parent_id, { inclusive: true }), id)) {
    session.showMessage('Cloned rows cannot be nested under themselves', {text_class: 'error'});
    return false;
  }
  return true;
};

export default class Mutation {
  public str() {
    return '';
  }
  public async validate(_session: Session): Promise<boolean> {
    return true;
  }
  public async mutate(_session: Session): Promise<void> {
    throw new errors.NotImplemented();
  }
  public async rewind(_session: Session): Promise<Array<Mutation>> {
    return [];
  }
  public async remutate(session: Session): Promise<void> {
    return this.mutate(session);
  }
  public async moveCursor(_cursor: Cursor): Promise<void> {
    return;
  }
}

export class AddChars extends Mutation {
  private row: Row;
  private col: Col;
  private chars: Array<Char>;

  constructor(row: Row, col: Col, chars: Array<Char>) {
    super();
    this.row = row;
    this.col = col;
    this.chars = chars;
  }

  public str() {
    return `row ${this.row}, col ${this.col}, nchars ${this.chars.length}`;
  }

  public async mutate(session: Session) {
    await session.document.writeChars(this.row, this.col, this.chars);
  }

  public async rewind() {
    return [
      new DelChars(this.row, this.col, this.chars.length),
    ];
  }

  public async moveCursor(cursor: Cursor) {
    if (!(cursor.path.row === this.row)) {
      return;
    }
    if (cursor.col >= this.col) {
      await cursor.setCol(cursor.col + this.chars.length);
    }
  }
}

export class DelChars extends Mutation {
  private row: Row;
  private col: Col;
  private nchars: number;
  public deletedChars: Line;

  constructor(row: Row, col: Col, nchars: number) {
    super();
    this.row = row;
    this.col = col;
    this.nchars = nchars;
  }

  public str() {
    return `row ${this.row}, col ${this.col}, nchars ${this.nchars}`;
  }

  public async mutate(session: Session) {
    this.deletedChars = await session.document.deleteChars(this.row, this.col, this.nchars);
  }

  public async rewind() {
    return [
      new AddChars(this.row, this.col, this.deletedChars),
    ];
  }

  public async moveCursor(cursor: Cursor) {
    if (cursor.row !== this.row) {
      return;
    }
    if (cursor.col < this.col) {
      return;
    } else if (cursor.col < this.col + this.nchars) {
      await cursor.setCol(this.col);
    } else {
      await cursor.setCol(cursor.col - this.nchars);
    }
  }
}

export class ChangeChars extends Mutation {
  private row: Row;
  private col: Col;
  private nchars: number;
  private transform?: (chars: Chars) => Chars;
  private newChars?: Array<Char>;
  private deletedChars: Array<Char>;
  public ncharsDeleted: number;

  constructor(
    row: Row, col: Col, nchars: number,
    transform?: (chars: Array<Char>) => Array<Char>, newChars?: Array<Char>,
  ) {
    super();
    this.row = row;
    this.col = col;
    this.nchars = nchars;
    this.transform = transform;
    this.newChars = newChars;
  }

  public str() {
    return `change row ${this.row}, col ${this.col}, nchars ${this.nchars}`;
  }

  public async mutate(session: Session) {
    this.deletedChars = await session.document.deleteChars(this.row, this.col, this.nchars);
    this.ncharsDeleted = this.deletedChars.length;
    if (this.transform) {
      this.newChars = this.transform(this.deletedChars);
      errors.assert(this.newChars.length === this.ncharsDeleted);
    }
    if (!this.newChars) {
      throw new Error('Changechars should receive either transform or newChars');
    }
    await session.document.writeChars(this.row, this.col, this.newChars);
  }

  public async rewind() {
    if (this.newChars == null) {
      throw new Error('No new chars after mutation?');
    }
    return [
      new ChangeChars(this.row, this.col, this.newChars.length, undefined, this.deletedChars),
    ];
  }

  public async remutate(session: Session) {
    if (this.newChars == null) {
      throw new Error('No new chars after mutation?');
    }
    await session.document.deleteChars(this.row, this.col, this.ncharsDeleted);
    await session.document.writeChars(this.row, this.col, this.newChars);
  }

  // doesn't move cursors
}

export class MoveBlock extends Mutation {
  private path: Path;
  private parent: Path;
  private old_parent: Path;
  private index: number;
  private old_index: number;

  constructor(path: Path, parent: Path, index: number) {
    super();
    this.path = path;
    this.parent = parent;
    if (this.path.parent == null) {
      throw new Error('Can\'t move root');
    }
    this.old_parent = this.path.parent;
    if (index === undefined) {
      this.index = -1;
    } else {
      this.index = index;
    }
  }

  public str() {
    return `move ${this.path.row} from ${this.old_parent.row} to ${this.parent.row}`;
  }

  public async validate(session: Session) {
    if (this.path.isRoot()) {
      session.showMessage('Cannot detach root', {text_class: 'error'});
      return false;
    }
    // if parent is the same, don't do sibling clone validation
    const sameParent = this.parent.row === this.old_parent.row;
    return await validateRowInsertion(session, this.parent.row, this.path.row, {noSiblingCheck: sameParent});
  }

  public async mutate(session: Session) {
    const info = await session.document._move(this.path.row, this.old_parent.row, this.parent.row, this.index);
    this.old_index = info.old.child_index;
  }

  public async rewind() {
    return [
      new MoveBlock(this.parent.extend([this.path.row]), this.old_parent, this.old_index),
    ];
  }

  public async moveCursor(cursor: Cursor) {
    const walk = cursor.path.walkFrom(this.path);
    if (walk === null) {
      return;
    }
    // TODO: other cursors could also
    // be on a relevant path..
    await cursor._setPath((this.parent.extend([this.path.row])).extend(walk));
  }
}

export class AttachBlocks extends Mutation {
  private parent: Row;
  private cloned_rows: Array<Row>;
  private nrows: number;
  private index: number;

  constructor(parent: Row, cloned_rows: Array<Row>, index: number) {
    super();
    this.parent = parent;
    this.cloned_rows = cloned_rows;
    this.nrows = this.cloned_rows.length;
    if (index === undefined) {
      this.index = -1;
    } else {
      this.index = index;
    }
  }

  public str() {
    return `parent ${this.parent}, index ${this.index}`;
  }

  public async validate(session: Session) {
    for (let i = 0; i < this.cloned_rows.length; i++) {
      const row = this.cloned_rows[i];
      if (!await validateRowInsertion(session, this.parent, row)) {
        return false;
      }
    }
    return true;
  }

  public async mutate(session: Session) {
    await session.document._attachChildren(this.parent, this.cloned_rows, this.index);
  }

  public async rewind() {
    return [
      new DetachBlocks(this.parent, this.index, this.nrows),
    ];
  }
}

type DetachBlocksOptions = {addNew?: boolean, noNew?: boolean};
export class DetachBlocks extends Mutation {
  private parent: Row;
  private index: number;
  private nrows: number;
  public deleted: Array<Row>;
  private next: SerializedPath;
  private created_info: AttachedChildInfo | null;
  private options: DetachBlocksOptions;

  constructor(parent: Row, index: number, nrows: number = 1, options: DetachBlocksOptions = {}) {
    super();
    this.parent = parent;
    this.index = index;
    this.nrows = nrows;
    this.options = options;
  }

  public str() {
    return `parent ${this.parent}, index ${this.index}, nrows ${this.nrows}`;
  }

  public async mutate(session: Session) {
    this.deleted = await session.document._getChildren(this.parent, this.index, this.index + this.nrows - 1);

    for (let i = 0; i < this.deleted.length; i++) {
      const row = this.deleted[i];
      await session.document._detach(row, this.parent);
    }

    this.created_info = null;
    if (this.options.addNew) {
      const info = await session.document._newChild(this.parent, this.index);
      this.created_info = info;
    }

    const children = await session.document._getChildren(this.parent);

    // a path, relative to the parent
    let next: Array<Row>;

    if (this.index < children.length) {
      next = [children[this.index]];
    } else {
      if (this.index === 0) {
        next = [];
        if (this.parent === session.document.root.row) {
          if (!this.options.noNew) {
            const info = await session.document._newChild(this.parent);
            this.created_info = info;
            next = [info.row];
          }
        }
      } else {
        const child = children[this.index - 1];
        const walk = await session.document.walkToLastVisible(child);
        next = [child].concat(walk);
      }
    }

    this.next = next;
  }

  public async rewind() {
    const mutations: Array<Mutation> = [];
    if (this.created_info !== null) {
      mutations.push(new DetachBlocks(this.parent, this.created_info.child_index, 1, {noNew: true}));
    }
    mutations.push(new AttachBlocks(this.parent, this.deleted, this.index));
    return mutations;
  }

  public async remutate(session: Session) {
    for (let i = 0; i < this.deleted.length; i++) {
      const row = this.deleted[i];
      await session.document._detach(row, this.parent);
    }
    if (this.created_info !== null) {
      await session.document._attach(this.created_info.row, this.parent, this.created_info.child_index);
    }
  }

  public async moveCursor(cursor: Cursor) {
    const result = cursor.path.shedUntil(this.parent);
    if (result === null) {
      return;
    }
    const [walk, ancestor] = result;
    if (walk.length === 0) {
      return;
    }
    const child = walk[0];
    if ((this.deleted.indexOf(child)) === -1) {
      return;
    }
    await cursor.setPosition(ancestor.extend(this.next), 0);
  }
}

// creates new blocks (as opposed to attaching ones that already exist)
export class AddBlocks extends Mutation {
  private parent: Path;
  private serialized_rows: Array<SerializedBlock>;
  private index: number;
  private nrows: number;
  public added_rows: Array<Path>;

  constructor(parent: Path, index: number, serialized_rows: Array<SerializedBlock>) {
    super();
    this.parent = parent;
    this.serialized_rows = serialized_rows;
    if (index === undefined) {
      this.index = -1;
    } else {
      this.index = index;
    }
    this.nrows = this.serialized_rows.length;
  }

  public str() {
    return `parent ${this.parent.row}, index ${this.index}`;
  }

  public async mutate(session: Session) {
    let index = this.index;

    const id_mapping = {};
    this.added_rows = [];
    for (let i = 0; i < this.serialized_rows.length; i++) {
      const serialized_row = this.serialized_rows[i];
      const row = await session.document.loadTo(serialized_row, this.parent, index, id_mapping);
      this.added_rows.push(row);
      index += 1;
    }
  }

  public async rewind() {
    return [
      new DetachBlocks(this.parent.row, this.index, this.nrows),
    ];
  }

  public async remutate(session: Session) {
    let index = this.index;
    for (let i = 0; i < this.added_rows.length; i++) {
      const sib = this.added_rows[i];
      await session.document.attachChild(this.parent, sib, index);
      index += 1;
    }
  }
}

export class ToggleBlock extends Mutation {
  private row: Row;

  constructor(row: Row) {
    super();
    this.row = row;
  }
  public str() {
    return `row ${this.row}`;
  }
  public async mutate(session: Session) {
    await session.document.toggleCollapsed(this.row);
  }
  public async rewind() {
    return [
      this,
    ];
  }
  // TODO: if a cursor is within the toggle block and their
  // viewRoot isn't, do a moveCursor?
}
