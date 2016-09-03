/*
mutations mutate a document within a session, and are undoable
each mutation should implement a constructor, as well as the following methods:

    str: () -> string
        prints itself
    mutate: (session) -> void
        takes a session and acts on it (mutates the session)
    rewind: (session) -> void
        takes a session, assumed be in the state right after the mutation was applied,
        and returns a list of mutations for undoing it

the mutation may also optionally implement

    validate: (session) -> bool
        returns whether this action is valid at the time (i.e. whether it is okay to call mutate)
    remutate: (session) -> void
        takes a session, and acts on it.  assumes that mutate has been called once already
        by default, remutate is the same as mutate.
        it should be implemented only if it is more efficient than the mutate implementation
    moveCursor: (cursor) -> void
        takes a cursor, and moves it according to how the cursor should move
*/

import _ from 'lodash';
import * as errors from './errors';

// validate inserting id as a child of parent_id
const validateRowInsertion = function(session, parent_id, id, options={}) {
  // check that there won't be doubled siblings
  if (!options.noSiblingCheck) {
    if (session.document._hasChild(parent_id, id)) {
      session.showMessage('Cloned rows cannot be inserted as siblings', {text_class: 'error'});
      return false;
    }
  }

  // check that there are no cycles
  // Precondition: tree is not already circular
  // It is sufficient to check if the row is an ancestor of the new parent,
  // because if there was a clone underneath the row which was an ancestor of 'parent',
  // then 'row' would also be an ancestor of 'parent'.
  if (_.includes((session.document.allAncestors(parent_id, { inclusive: true })), id)) {
    session.showMessage('Cloned rows cannot be nested under themselves', {text_class: 'error'});
    return false;
  }
  return true;
};

export default class Mutation {
  str() {
    return '';
  }
  validate(/* session */) {
    return true;
  }
  mutate(/* session */) {

  }
  rewind(/* session */) {
    return [];
  }
  remutate(session) {
    return this.mutate(session);
  }
  moveCursor(/* cursor */) {

  }
}

export class AddChars extends Mutation {
  constructor(row, col, chars) {
    super();
    this.row = row;
    this.col = col;
    this.chars = chars;
  }

  str() {
    return `row ${this.row}, col ${this.col}, nchars ${this.chars.length}`;
  }

  mutate(session) {
    return session.document.writeChars(this.row, this.col, this.chars);
  }

  rewind(/* session */) {
    return [
      /* eslint-disable no-use-before-define */
      new DelChars(this.row, this.col, this.chars.length)
      /* eslint-enable no-use-before-define */
    ];
  }

  moveCursor(cursor) {
    if (!(cursor.path.row === this.row)) {
      return;
    }
    if (cursor.col >= this.col) {
      return cursor.setCol(cursor.col + this.chars.length);
    }
  }
}

export class DelChars extends Mutation {
  constructor(row, col, nchars) {
    super();
    this.row = row;
    this.col = col;
    this.nchars = nchars;
  }

  str() {
    return `row ${this.row}, col ${this.col}, nchars ${this.nchars}`;
  }

  mutate(session) {
    return this.deletedChars = session.document.deleteChars(this.row, this.col, this.nchars);
  }

  rewind(/* session */) {
    return [
      new AddChars(this.row, this.col, this.deletedChars)
    ];
  }

  moveCursor(cursor) {
    if (cursor.row !== this.row) {
      return;
    }
    if (cursor.col < this.col) {
      return;
    } else if (cursor.col < this.col + this.nchars) {
      return cursor.setCol(this.col);
    } else {
      return cursor.setCol(cursor.col - this.nchars);
    }
  }
}

export class ChangeChars extends Mutation {
  constructor(row, col, nchars, transform, newChars) {
    super();
    this.row = row;
    this.col = col;
    this.nchars = nchars;
    this.transform = transform;
    this.newChars = newChars;
  }

  str() {
    return `change row ${this.row}, col ${this.col}, nchars ${this.nchars}`;
  }

  mutate(session) {
    this.deletedChars = session.document.deleteChars(this.row, this.col, this.nchars);
    this.ncharsDeleted = this.deletedChars.length;
    if (this.transform) {
      this.newChars = this.transform(this.deletedChars);
      errors.assert((this.newChars.length === this.ncharsDeleted));
    }
    return session.document.writeChars(this.row, this.col, this.newChars);
  }

  rewind(/* session */) {
    return [
      new ChangeChars(this.row, this.col, this.newChars.length, null, this.deletedChars)
    ];
  }

  remutate(session) {
    session.document.deleteChars(this.row, this.col, this.ncharsDeleted);
    return session.document.writeChars(this.row, this.col, this.newChars);
  }

  // doesn't move cursors
}

export class MoveBlock extends Mutation {
  constructor(path, parent, index) {
    super();
    this.path = path;
    this.parent = parent;
    this.old_parent = this.path.parent;
    if (index === undefined) {
      this.index = -1;
    } else {
      this.index = index;
    }
  }

  str() {
    return `move ${this.path.row} from ${this.path.parent.row} to ${this.parent.row}`;
  }

  validate(session) {
    // if parent is the same, don't do sibling clone validation
    const sameParent = this.parent.row === this.old_parent.row;
    return (validateRowInsertion(session, this.parent.row, this.path.row, {noSiblingCheck: sameParent}));
  }

  mutate(session) {
    errors.assert((!this.path.isRoot()), 'Cannot detach root');
    const info = session.document._move(this.path.row, this.old_parent.row, this.parent.row, this.index);
    return this.old_index = info.old.childIndex;
  }

  rewind(/* session */) {
    return [
      new MoveBlock((this.parent.extend([this.path.row])), this.old_parent, this.old_index)
    ];
  }

  moveCursor(cursor) {
    const walk = cursor.path.walkFrom(this.path);
    if (walk === null) {
      return;
    }
    // TODO: other cursors could also
    // be on a relevant path..
    return cursor._setPath((this.parent.extend([this.path.row])).extend(walk));
  }
}

export class AttachBlocks extends Mutation {
  constructor(parent, cloned_rows, index, options) {
    super();
    this.parent = parent;
    this.cloned_rows = cloned_rows;
    this.nrows = this.cloned_rows.length;
    if (index === undefined) {
      this.index = -1;
    } else {
      this.index = index;
    }
    this.options = options || {};
  }

  str() {
    return `parent ${this.parent}, index ${this.index}`;
  }

  validate(session) {
    for (let i = 0; i < this.cloned_rows.length; i++) {
      const row = this.cloned_rows[i];
      if (!(validateRowInsertion(session, this.parent, row))) {
        return false;
      }
    }
    return true;
  }

  mutate(session) {
    return session.document._attachChildren(this.parent, this.cloned_rows, this.index);
  }

  rewind(/* session */) {
    return [
      /* eslint-disable no-use-before-define */
      new DetachBlocks(this.parent, this.index, this.nrows)
      /* eslint-enable no-use-before-define */
    ];
  }
}

export class DetachBlocks extends Mutation {
  constructor(parent, index, nrows, options) {
    super();
    this.parent = parent;
    this.index = index;
    this.nrows = nrows || 1;
    this.options = options || {};
  }

  str() {
    return `parent ${this.parent}, index ${this.index}, nrows ${this.nrows}`;
  }

  mutate(session) {
    this.deleted = session.document._getChildren(this.parent, this.index, ((this.index+this.nrows)-1))
      .filter((sib => sib !== null));

    for (let i = 0; i < this.deleted.length; i++) {
      const row = this.deleted[i];
      session.document._detach(row, this.parent);
    }

    this.created = null;
    if (this.options.addNew) {
      this.created = session.document._newChild(this.parent, this.index);
      this.created_index = session.document._childIndex(this.parent, this.created);
    }

    const children = session.document._getChildren(this.parent);

    // note: next is a path, relative to the parent

    let next;
    if (this.index < children.length) {
      next = [children[this.index]];
    } else {
      if (this.index === 0) {
        next = [];
        if (this.parent === session.document.root.row) {
          if (!this.options.noNew) {
            this.created = session.document._newChild(this.parent);
            this.created_index = session.document._childIndex(this.parent, this.created);
            next = [this.created];
          }
        }
      } else {
        const child = children[this.index - 1];
        const walk = session.document.walkToLastVisible(child);
        next = [child].concat(walk);
      }
    }

    return this.next = next;
  }

  rewind(/* session */) {
    const mutations = [];
    if (this.created !== null) {
      mutations.push(new DetachBlocks(this.parent, this.created_index, 1, {noNew: true}));
    }
    mutations.push(new AttachBlocks(this.parent, this.deleted, this.index));
    return mutations;
  }

  remutate(session) {
    this.deleted.forEach((row) => {
      session.document._detach(row, this.parent);
    });
    if (this.created !== null) {
      return session.document._attach(this.created, this.parent, this.created_index);
    }
  }

  moveCursor(cursor) {
    const [walk, ancestor] = cursor.path.shedUntil(this.parent);
    if (walk === null) {
      return;
    }
    if (walk.length === 0) {
      return;
    }
    const child = walk[0];
    if ((this.deleted.indexOf(child)) === -1) {
      return;
    }
    return cursor.setPosition(ancestor.extend(this.next), 0);
  }
}

// creates new blocks (as opposed to attaching ones that already exist)
export class AddBlocks extends Mutation {
  constructor(parent, index, serialized_rows) {
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

  str() {
    return `parent ${this.parent.row}, index ${this.index}`;
  }

  mutate(session) {
    let index = this.index;

    const id_mapping = {};
    this.added_rows = [];
    this.serialized_rows.forEach((serialized_row) => {
      const row = session.document.loadTo(serialized_row, this.parent, index, id_mapping);
      this.added_rows.push(row);
      index += 1;
    });
    return null;
  }

  rewind(/* session */) {
    return [
      new DetachBlocks(this.parent.row, this.index, this.nrows)
    ];
  }

  remutate(session) {
    let index = this.index;
    this.added_rows.forEach((sib) => {
      session.document.attachChild(this.parent, sib, index);
      index += 1;
    });
    return null;
  }
}

export class ToggleBlock extends Mutation {
  constructor(row) {
    super();
    this.row = row;
  }
  str() {
    return `row ${this.row}`;
  }
  mutate(session) {
    return session.document.toggleCollapsed(this.row);
  }
  rewind(/* session */) {
    return [
      this
    ];
  }
  // TODO: if a cursor is within the toggle block and their
  // viewRoot isn't, do a moveCursor?
}
