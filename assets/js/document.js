import _ from 'lodash';
import * as utils from './utils';
import * as errors from './errors';
import * as constants from './constants';
// import * as Logger from './logger';
import EventEmitter from './eventEmitter';
import Path from './path';

/*
Document is a wrapper class around the actual datastore, providing methods to manipulate the document
the document itself includes:
  - the text in each line, including text properties like bold/italic
  - the parent/child relationships and collapsed-ness of lines
also deals with loading the initial document from the datastore, and serializing the document to a string

Currently, the separation between the Session and Document classes is not very good.  (see session.js)
*/
class Document extends EventEmitter {
  constructor(store) {
    super();
    this.store = store;
    this.root = Path.getRoot();
    return this;
  }

  //########
  // lines #
  //########

  // an array of objects:
  // {
  //   char: 'a'
  //   bold: true
  //   italic: false
  // }
  // in the case where all properties are false, it may be simply the character (to save space)
  getLine(row) {
    return (this.store.getLine(row)).map(function(obj) {
      if (typeof obj === 'string') {
        obj = {
          char: obj
        };
      }
      return obj;
    });
  }

  getText(row) {
    return this.getLine(row).map((obj => obj.char));
  }

  getChar(row, col) {
    let charInfo = this.getLine(row)[col];
    return charInfo && charInfo.char;
  }

  setLine(row, line) {
    return (this.store.setLine(row, (line.map(function(obj) {
      // if no properties are true, serialize just the character to save space
      if (_.every(constants.text_properties.map((property => !obj[property])))) {
        return obj.char;
      } else {
        return obj;
      }

    }))
    ));
  }

  // get word at this location
  // if on a whitespace character, return nothing
  getWord(row, col) {
    let text = this.getText(row);

    if (utils.isWhitespace(text[col])) {
      return '';
    }

    let start = col;
    let end = col;
    while ((start > 0) && !(utils.isWhitespace(text[start-1]))) {
      start -= 1;
    }
    while ((end < text.length - 1) && !(utils.isWhitespace(text[end+1]))) {
      end += 1;
    }
    let word = text.slice(start, end + 1).join('');
    // remove leading and trailing punctuation
    word = word.replace(/^[-.,()&$#!\[\]{}"']+/g, '');
    word = word.replace(/[-.,()&$#!\[\]{}"']+$/g, '');
    return word;
  }

  writeChars(row, col, chars) {
    let args = [col, 0].concat(chars);
    let line = this.getLine(row);
    [].splice.apply(line, args);
    return this.setLine(row, line);
  }

  deleteChars(row, col, num) {
    let line = this.getLine(row);
    let deleted = line.splice(col, num);
    this.setLine(row, line);
    return deleted;
  }

  getLength(row) {
    return this.getLine(row).length;
  }

  //############
  // structure #
  //############

  _getChildren(row, min=0, max=-1) {
    let children = this.store.getChildren(row);
    if (children.length === 0) {
      return [];
    }
    if (max === -1) {
      max = children.length - 1;
    }
    let indices = [];
    for (let i = min; i <= max; i++) {
      indices.push(i);
    }
    return indices.map(function(index) {
      if (index >= children.length) {
        return null;
      } else if (index < 0) {
        return null;
      } else {
        return children[index];
      }
    });
  }

  _setChildren(row, children) {
    return this.store.setChildren(row, children);
  }

  _childIndex(parent, child) {
    let children = this._getChildren(parent);
    return _.findIndex(children, row => row === child
    );
  }

  _getParents(row) {
    return this.store.getParents(row);
  }

  _setParents(row, children_rows) {
    return this.store.setParents(row, children_rows);
  }

  getChildren(parent_path) {
    return (this._getChildren(parent_path.row)).map(row => parent_path.child(row));
  }

  findChild(parent_path, row) {
    return _.find((this.getChildren(parent_path)), (x => x.row === row));
  }

  hasChildren(row) {
    return ((this._getChildren(row)).length > 0);
  }

  getSiblings(row) {
    return this.getChildren(row.parent);
  }

  nextClone(path) {
    let parents = this._getParents(path.row);
    let i = parents.indexOf(path.parent.row);
    errors.assert(i > -1);
    let new_parent_path;
    while (true) {
      i = (i + 1) % parents.length;
      let new_parent = parents[i];
      new_parent_path = this.canonicalPath(new_parent);
      // this happens if the parent got detached
      if (new_parent_path !== null) {
        break;
      }
    }
    return new_parent_path.child(path.row);
  }

  indexOf(child) {
    let children = this.getSiblings(child);
    return _.findIndex(children, sib => sib.row === child.row
    );
  }

  collapsed(row) {
    return this.store.getCollapsed(row);
  }

  toggleCollapsed(row) {
    return this.store.setCollapsed(row, (!this.collapsed(row)));
  }

  // last thing visible nested within row
  walkToLastVisible(row, pathsofar=[]) {
    if (this.collapsed(row)) {
      return pathsofar;
    }
    let children = this._getChildren(row);
    if (children.length === 0) {
      return pathsofar;
    }
    let child = children[children.length - 1];
    return [child].concat(this.walkToLastVisible(child));
  }

  // a node is cloned only if it has multiple parents.
  // note that this may return false even if it appears multiple times in the display (if its ancestor is cloned)
  isClone(row) {
    let parents = this._getParents(row);
    if (parents.length < 2) { // for efficiency reasons
      return false;
    }
    let numAttachedParents = (parents.filter(parent => this.isAttached(parent))).length;
    return numAttachedParents > 1;
  }

  // Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
  // NOTE: this is not very efficient, in the worst case, but probably doesn't matter
  canonicalPath(row) { // Given an row, return a path with that row
    errors.assert((row != null), 'Empty row passed to canonicalPath');
    if (row === constants.root_row) {
      return this.root;
    }
    let iterable = this._getParents(row);
    for (let i = 0; i < iterable.length; i++) {
      let parentRow = iterable[i];
      let canonicalParent = this.canonicalPath(parentRow);
      if (canonicalParent !== null) {
        return this.findChild(canonicalParent, row);
      }
    }
    return null;
  }

  // Return all ancestor rows, topologically sorted (root is *last*).
  // Excludes 'row' itself unless options.inclusive is specified
  // NOTE: includes possibly detached nodes
  allAncestors(row, options) {
    options = _.defaults({}, options, { inclusive: false });
    let visited = {};
    let ancestors = []; // 'visited' with preserved insert order
    if (options.inclusive) {
      ancestors.push(row);
    }
    let visit = n => { // DFS
      visited[n] = true;
      let iterable = this._getParents(n);
      for (let i = 0; i < iterable.length; i++) {
        let parent = iterable[i];
        if (!(parent in visited)) {
          ancestors.push(parent);
          visit(parent);
        }
      }
      return null;
    };
    visit(row);
    return ancestors;
  }

  // detach a block from the graph
  detach(path) {
    let { parent } = path;
    let index = this.indexOf(path);
    this._detach(path.row, parent.row);
    return {
      parent,
      index
    };
  }

  _hasChild(parent_row, row) {
    let children = this._getChildren(parent_row);
    let ci = _.findIndex(children, sib => sib === row);
    return ci !== -1;
  }

  _removeChild(parent_row, row) {
    let children = this._getChildren(parent_row);
    let ci = _.findIndex(children, sib => sib === row);
    errors.assert((ci !== -1));
    children.splice(ci, 1);
    this._setChildren(parent_row, children);

    let parents = this._getParents(row);
    let pi = _.findIndex(parents, par => par === parent_row);
    parents.splice(pi, 1);
    this._setParents(row, parents);

    let info = {
      parentId: parent_row,
      parentIndex: pi,
      childId: row,
      childIndex: ci,
    };
    this.emit('childRemoved', info);
    return info;
  }

  _addChild(parent_row, row, index) {
    let children = this._getChildren(parent_row);
    errors.assert((index <= children.length));
    if (index === -1) {
      children.push(row);
    } else {
      children.splice(index, 0, row);
    }
    this._setChildren(parent_row, children);

    let parents = this._getParents(row);
    parents.push(parent_row);
    this._setParents(row, parents);
    let info = {
      parentId: parent_row,
      parentIndex: parents.length - 1,
      childId: row,
      childIndex: index,
    };
    this.emit('childAdded', info);
    return info;
  }

  _detach(row, parent_row) {
    let wasLast = (this._getParents(row)).length === 1;

    this.emit('beforeDetach', { id: row, parent_id: parent_row, last: wasLast });
    let info = this._removeChild(parent_row, row);
    if (wasLast) {
      this.store.setDetachedParent(row, parent_row);
      let detached_children = this.store.getDetachedChildren(parent_row);
      detached_children.push(row);
      this.store.setDetachedChildren(parent_row, detached_children);
    }
    this.emit('afterDetach', { id: row, parent_id: parent_row, last: wasLast });
    return info;
  }

  _attach(child_row, parent_row, index = -1) {
    let isFirst = (this._getParents(child_row)).length === 0;
    this.emit('beforeAttach', { id: child_row, parent_id: parent_row, first: isFirst});
    let info = this._addChild(parent_row, child_row, index);
    let old_detached_parent = this.store.getDetachedParent(child_row);
    if (old_detached_parent !== null) {
      errors.assert(isFirst);
      this.store.setDetachedParent(child_row, null);
      let detached_children = this.store.getDetachedChildren(old_detached_parent);
      let ci = _.findIndex(detached_children, sib => sib === child_row);
      errors.assert((ci !== -1));
      detached_children.splice(ci, 1);
      this.store.setDetachedChildren(old_detached_parent, detached_children);
    }
    this.emit('afterAttach', { id: child_row, parent_id: parent_row, first: isFirst, old_detached_parent});
    return info;
  }

  _move(child_row, old_parent_row, new_parent_row, index = -1) {
    this.emit('beforeMove', { id: child_row, old_parent: old_parent_row, new_parent: new_parent_row });

    let remove_info = this._removeChild(old_parent_row, child_row);
    if ((old_parent_row === new_parent_row) && (index > remove_info.childIndex)) {
      index = index - 1;
    }
    let add_info = this._addChild(new_parent_row, child_row, index);

    this.emit('afterMove', { id: child_row, old_parent: old_parent_row, new_parent: new_parent_row });

    return {
      old: remove_info,
      new: add_info
    };
  }

  // attaches a detached child to a parent
  // the child should not have a parent already
  attachChild(parent, child, index = -1) {
    return (this.attachChildren(parent, [child], index))[0];
  }

  attachChildren(parent, new_children, index = -1) {
    this._attachChildren(parent.row, new_children.map(x => x.row), index);
    // for child in new_children
    //   child.setParent parent
    return new_children;
  }

  _attachChildren(parent, new_children, index = -1) {
    for (let i = 0; i < new_children.length; i++) {
      let child = new_children[i];
      this._attach(child, parent, index);
      if (index >= 0) {
        index += 1;
      }
    }
    return null;
  }

  // returns an array representing the ancestry of a row,
  // up until the ancestor specified by the `stop` parameter
  // i.e. [stop, stop's child, ... , row's parent , row]
  getAncestry(row, stop) {
    if (stop === undefined) {
      stop = this.root;
    }
    let ancestors = [];
    while (!row.is(stop)) {
      errors.assert((!row.isRoot()), `Failed to get ancestry for ${row} going up until ${stop}`);
      ancestors.push(row);
      row = row.parent;
    }
    ancestors.push(stop);
    ancestors.reverse();
    return ancestors;
  }

  // given two rows, returns
  // 1. the common ancestor of the rows
  // 2. the array of ancestors between common ancestor and row1
  // 3. the array of ancestors between common ancestor and row2
  getCommonAncestor(row1, row2) {
    let ancestors1 = this.getAncestry(row1);
    let ancestors2 = this.getAncestry(row2);
    let commonAncestry = _.takeWhile(
      _.zip(ancestors1, ancestors2),
      pair =>
        (pair[0] !== undefined) && (pair[1] !== undefined) && pair[0].is(pair[1])
    );
    let common = (_.last(commonAncestry))[0];
    let firstDifference = commonAncestry.length;
    return [common, ancestors1.slice(firstDifference), ancestors2.slice(firstDifference)];
  }

  // extends a path by a list of rows going downwards (used when moving blocks around)
  combineAncestry(path, row_path) {
    for (let i = 0; i < row_path.length; i++) {
      let row = row_path[i];
      path = this.findChild(path, row);
      if (path == null) {
        return null;
      }
    }
    return path;
  }

  // returns whether an row is actually reachable from the root node
  // if something is not detached, it will have a parent, but the parent wont mention it as a child
  isAttached(row) {
    return this.allAncestors(row, {inclusive: true}).indexOf(this.root.row) !== -1;
  }

  getSiblingBefore(path) {
    return this.getSiblingOffset(path, -1);
  }

  getSiblingAfter(path) {
    return this.getSiblingOffset(path, 1);
  }

  getSiblingOffset(path, offset) {
    return (this.getSiblingRange(path, offset, offset))[0];
  }

  getSiblingRange(path, min_offset, max_offset) {
    let index = this.indexOf(path);
    return this.getChildRange(path.parent, (min_offset + index), (max_offset + index));
  }

  getChildRange(path, min, max) {
    return (this._getChildren(path.row, min, max)).map((function(child_row) {
      if (child_row === null) {
        return null;
      }
      return path.child(child_row);
    })
    );
  }

  _newChild(parent, index = -1) {
    let row = this.store.getNew();
    this._attach(row, parent, index);
    return row;
  }

  addChild(path, index = -1) {
    let row = this._newChild(path.row, index);
    return (path.child(row));
  }

  orderedLines() {
    // TODO: deal with clones
    let paths = [];

    let helper = path => {
      paths.push(path);
      let iterable = this.getChildren(path);
      for (let i = 0; i < iterable.length; i++) {
        let child = iterable[i];
        helper(child);
      }
      return null;
    };
    helper(this.root);
    return paths;
  }

  //################
  // serialization #
  //################

  // important: serialized automatically garbage collects
  serializeRow(row = this.root.row) {
    let line = this.getLine(row);
    let text = (this.getText(row)).join('');
    let struct = {
      text
    };

    for (let i = 0; i < constants.text_properties.length; i++) {
      let property = constants.text_properties[i];
      if (_.some(line.map((obj => obj[property])))) {
        struct[property] = line.map((obj) => obj[property] ? '.' : ' ').join('');
      }
    }
    if (this.collapsed(row)) {
      struct.collapsed = true;
    }

    struct = this.applyHook('serializeRow', struct, {row});
    return struct;
  }

  serialize(row = this.root.row, options={}, serialized={}) {
    if (row in serialized) {
      let struct = serialized[row];
      struct.id = row;
      return { clone: row };
    }

    var struct = this.serializeRow(row);
    let children = this._getChildren(row).map(
      (childrow) => { return this.serialize(childrow, options, serialized); }
    );
    if (children.length) {
      struct.children = children;
    }

    serialized[row] = struct;

    if (options.pretty) {
      if (children.length === 0 && (!this.isClone(row)) &&
          (_.every(Object.keys(struct), key => key === 'children' || key === 'text' || key === 'collapsed'
          ))) {
        return struct.text;
      }
    }
    return struct;
  }

  loadTo(serialized, parent_path = this.root, index = -1, id_mapping = {}, replace_empty = false) {
    if (serialized.clone) {
      // NOTE: this assumes we load in the same order we serialize
      errors.assert((serialized.clone in id_mapping));
      let row = id_mapping[serialized.clone];
      let path = parent_path.child(row);
      this.attachChild(parent_path, path, index);
      return path;
    }

    let children = this.getChildren(parent_path);
    // if parent_path has only one child and it's empty, delete it
    let path;
    if (replace_empty && children.length === 1 && ((this.getLine(children[0].row)).length === 0)) {
      path = children[0];
    } else {
      path = this.addChild(parent_path, index);
    }

    if (typeof serialized === 'string') {
      this.setLine(path.row, (serialized.split('')));
    } else {
      if (serialized.id) {
        id_mapping[serialized.id] = path.row;
      }
      let line = (serialized.text.split('')).map(char => ({char}));
      for (let j = 0; j < constants.text_properties.length; j++) {
        let property = constants.text_properties[j];
        if (serialized[property]) {
          for (let i in serialized[property]) {
            let val = serialized[property][i];
            if (val === '.') {
              line[i][property] = true;
            }
          }
        }
      }

      this.setLine(path.row, line);
      this.store.setCollapsed(path.row, serialized.collapsed);

      if (serialized.children) {
        for (let k = 0; k < serialized.children.length; k++) {
          let serialized_child = serialized.children[k];
          this.loadTo(serialized_child, path, -1, id_mapping);
        }
      }
    }

    this.emit('loadRow', path, serialized);

    return path;
  }

  load(serialized_rows) {
    let id_mapping = {};
    for (let i = 0; i < serialized_rows.length; i++) {
      let serialized_row = serialized_rows[i];
      this.loadTo(serialized_row, this.root, -1, id_mapping, true);
    }
    return null;
  }
}

// exports
export default Document;
