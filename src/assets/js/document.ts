import * as _ from 'lodash';

import * as utils from './utils';
import * as errors from './errors';
import * as constants from './constants';
// import logger from './logger';
import EventEmitter from './eventEmitter';
import Path from './path';
import DataStore from './datastore';
import { SerializedLine } from './types';

/*
Document is a wrapper class around the actual datastore, providing methods to manipulate the document
the document itself includes:
  - the text in each line, including text properties like bold/italic
  - the parent/child relationships and collapsed-ness of lines
also deals with loading the initial document from the datastore, and serializing the document to a string

Currently, the separation between the Session and Document classes is not very good.  (see session.js)
*/

type SearchOptions = {nresults?: number, case_sensitive?: boolean};

export default class Document extends EventEmitter {
  public store: DataStore;
  public name: string;
  public root: Path;

  constructor(store, name = '') {
    super();
    this.store = store;
    this.name = name;
    this.root = Path.root();
    return this;
  }

  public async getLine(row) {
    return await this.store.getLine(row);
  }

  public async getChars(row) {
    return (await this.getLine(row)).map(obj => obj.char);
  }

  public async getText(row): Promise<string> {
    return (await this.getChars(row)).join('');
  }

  public async getChar(row, col) {
    const charInfo = (await this.getLine(row))[col];
    return charInfo && charInfo.char;
  }

  public async setLine(row, line) {
    await this.store.setLine(row, line);
  }

  // get word at this location
  // if on a whitespace character, return nothing
  public async getWord(row, col) {
    const text = await this.getChars(row);

    if (utils.isWhitespace(text[col])) {
      return '';
    }

    let start = col;
    let end = col;
    while ((start > 0) && !utils.isWhitespace(text[start - 1])) {
      start -= 1;
    }
    while ((end < text.length - 1) && !utils.isWhitespace(text[end + 1])) {
      end += 1;
    }
    let word = text.slice(start, end + 1).join('');
    // remove leading and trailing punctuation
    word = word.replace(/^[-.,()&$#!\[\]{}"']+/g, '');
    word = word.replace(/[-.,()&$#!\[\]{}"']+$/g, '');
    return word;
  }

  public async writeChars(row, col, chars) {
    const args = [col, 0].concat(chars);
    const line = await this.getLine(row);
    [].splice.apply(line, args);
    return await this.setLine(row, line);
  }

  public async deleteChars(row, col, num) {
    const line = await this.getLine(row);
    const deleted = line.splice(col, num);
    await this.setLine(row, line);
    return deleted;
  }

  public async getLength(row) {
    return (await this.getLine(row)).length;
  }

  // structure

  public async _getChildren(row, min = 0, max = -1) {
    return this._getSlice(await this.store.getChildren(row), min, max);
  }

  private _getSlice(array, min, max) {
    if (array.length === 0) {
      return [];
    }
    if (max === -1) { max = array.length - 1; }
    const indices = [];
    for (let i = min; i <= max; i++) {
      indices.push(i);
    }
    return indices.map(function(index) {
      if (index >= array.length) {
        return null;
      } else if (index < 0) {
        return null;
      } else {
        return array[index];
      }
    });
  }

  private async _setChildren(row, children) {
    return await this.store.setChildren(row, children);
  }

  public async _childIndex(parent, child) {
    const children = await this._getChildren(parent);
    return _.findIndex(children, row => row === child);
  }

  private async _getParents(row) {
    return await this.store.getParents(row);
  }

  private async _setParents(row, children_rows) {
    return await this.store.setParents(row, children_rows);
  }

  public async getChildren(parent_path): Promise<Array<Path>> {
    return (await this._getChildren(parent_path.row)).map(row => parent_path.child(row));
  }

  public async findChild(parent_path, row) {
    return _.find(await this.getChildren(parent_path), x => x.row === row);
  }

  public async hasChildren(row) {
    return (await this._getChildren(row)).length > 0;
  }

  public async getSiblings(path) {
    if (path.isRoot()) {
      return [path];
    }
    return await this.getChildren(path.parent);
  }

  public async nextClone(path) {
    const parents = await this._getParents(path.row);
    let i = parents.indexOf(path.parent.row);
    errors.assert(i > -1);
    let new_parent_path;
    while (true) {
      i = (i + 1) % parents.length;
      let new_parent = parents[i];
      new_parent_path = await this.canonicalPath(new_parent);
      // this happens if the parent got detached
      if (new_parent_path !== null) {
        break;
      }
    }
    return new_parent_path.child(path.row);
  }

  public async indexInParent(child) {
    const children = await this.getSiblings(child);
    return _.findIndex(children, sib => sib.row === child.row);
  }

  public async collapsed(row) {
    return await this.store.getCollapsed(row);
  }

  public async toggleCollapsed(row) {
    return await this.store.setCollapsed(row, !await this.collapsed(row));
  }

  // last thing visible nested within row
  public async walkToLastVisible(row, pathsofar = []) {
    if (await this.collapsed(row)) {
      return pathsofar;
    }
    const children = await this._getChildren(row);
    if (children.length === 0) {
      return pathsofar;
    }
    const child = children[children.length - 1];
    return [child].concat(await this.walkToLastVisible(child));
  }

  // a node is cloned only if it has multiple parents.
  // note that this may return false even if it appears multiple times in the display (if its ancestor is cloned)
  public async isClone(row) {
    const parents = await this._getParents(row);
    if (parents.length < 2) { // for efficiency reasons
      return false;
    }
    const numAttachedParents = parents.filter(parent => this.isAttached(parent)).length;
    return numAttachedParents > 1;
  }

  // Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
  // NOTE: this is not very efficient, in the worst case, but probably doesn't matter
  public async canonicalPath(row) { // Given an row, return a path with that row
    errors.assert(row !== null, 'Empty row passed to canonicalPath');
    if (row === Path.rootRow()) {
      return this.root;
    }
    const parents = await this._getParents(row);
    for (let i = 0; i < parents.length; i++) {
      const parentRow = parents[i];
      const canonicalParent = await this.canonicalPath(parentRow);
      if (canonicalParent !== null) {
        return await this.findChild(canonicalParent, row);
      }
    }
    return null;
  }

  // Return all ancestor rows, topologically sorted (root is *last*).
  // Excludes 'row' itself unless options.inclusive is specified
  // NOTE: includes possibly detached nodes
  public async allAncestors(row, options) {
    options = _.defaults({}, options, { inclusive: false });
    const visited = {};
    const ancestors = []; // 'visited' with preserved insert order
    if (options.inclusive) {
      ancestors.push(row);
    }
    const visit = async (n) => { // DFS
      visited[n] = true;
      const parents = await this._getParents(n);
      for (let i = 0; i < parents.length; i++) {
        const parent = parents[i];
        if (!(parent in visited)) {
          ancestors.push(parent);
          await visit(parent);
        }
      }
      return null;
    };
    await visit(row);
    return ancestors;
  }

  public async _hasChild(parent_row, row) {
    const children = await this._getChildren(parent_row);
    const ci = _.findIndex(children, sib => sib === row);
    return ci !== -1;
  }

  private async _removeChild(parent_row, row) {
    const children = await this._getChildren(parent_row);
    const ci = _.findIndex(children, sib => sib === row);
    errors.assert(ci !== -1);
    children.splice(ci, 1);
    await this._setChildren(parent_row, children);

    const parents = await this._getParents(row);
    const pi = _.findIndex(parents, par => par === parent_row);
    parents.splice(pi, 1);
    await this._setParents(row, parents);

    const info = {
      parentId: parent_row,
      parentIndex: pi,
      childId: row,
      childIndex: ci,
    };
    this.emit('childRemoved', info);
    return info;
  }

  private async _addChild(parent_row, row, index) {
    const children = await this._getChildren(parent_row);
    errors.assert(index <= children.length);
    if (index === -1) {
      children.push(row);
    } else {
      children.splice(index, 0, row);
    }
    await this._setChildren(parent_row, children);

    const parents = await this._getParents(row);
    parents.push(parent_row);
    await this._setParents(row, parents);
    const info = {
      parentId: parent_row,
      parentIndex: parents.length - 1,
      childId: row,
      childIndex: index,
    };
    this.emit('childAdded', info);
    return info;
  }

  public async _detach(row, parent_row) {
    const wasLast = (await this._getParents(row)).length === 1;

    await this.emitAsync('beforeDetach', { id: row, parent_id: parent_row, last: wasLast });
    const info = await this._removeChild(parent_row, row);
    if (wasLast) {
      await this.store.setDetachedParent(row, parent_row);
      const detached_children = await this.store.getDetachedChildren(parent_row);
      detached_children.push(row);
      await this.store.setDetachedChildren(parent_row, detached_children);
    }
    await this.emitAsync('afterDetach', { id: row, parent_id: parent_row, last: wasLast });
    return info;
  }

  public async _attach(child_row, parent_row, index = -1) {
    const isFirst = (await this._getParents(child_row)).length === 0;
    await this.emitAsync('beforeAttach', { id: child_row, parent_id: parent_row, first: isFirst});
    const info = await this._addChild(parent_row, child_row, index);
    const old_detached_parent = await this.store.getDetachedParent(child_row);
    if (old_detached_parent !== null) {
      errors.assert(isFirst);
      await this.store.setDetachedParent(child_row, null);
      const detached_children = await this.store.getDetachedChildren(old_detached_parent);
      const ci = _.findIndex(detached_children, sib => sib === child_row);
      errors.assert(ci !== -1);
      detached_children.splice(ci, 1);
      await this.store.setDetachedChildren(old_detached_parent, detached_children);
    }
    await this.emitAsync('afterAttach', { id: child_row, parent_id: parent_row, first: isFirst, old_detached_parent});
    return info;
  }

  public async _move(child_row, old_parent_row, new_parent_row, index = -1) {
    await this.emitAsync('beforeMove', {
      id: child_row, old_parent: old_parent_row, new_parent: new_parent_row,
    });

    const remove_info = await this._removeChild(old_parent_row, child_row);
    if ((old_parent_row === new_parent_row) && (index > remove_info.childIndex)) {
      index = index - 1;
    }
    const add_info = await this._addChild(new_parent_row, child_row, index);

    await this.emitAsync('afterMove', {
      id: child_row, old_parent: old_parent_row, new_parent: new_parent_row,
    });

    return {
      old: remove_info,
      new: add_info,
    };
  }

  // attaches a detached child to a parent
  // the child should not have a parent already
  public async attachChild(parent, child, index = -1) {
    return await this.attachChildren(parent, [child], index)[0];
  }

  public async attachChildren(parent, new_children, index = -1) {
    await this._attachChildren(parent.row, new_children.map(x => x.row), index);
    // for child in new_children
    //   child.setParent parent
    return new_children;
  }

  private async _attachChildren(parent, new_children, index = -1) {
    for (let i = 0; i < new_children.length; i++) {
      const child = new_children[i];
      await this._attach(child, parent, index);
      if (index >= 0) {
        index += 1;
      }
    }
    return null;
  }

  // given two paths, returns
  // 1. the common ancestor of the paths
  // 2. the array of ancestors between common ancestor and path1
  // 3. the array of ancestors between common ancestor and path2
  public async getCommonAncestor(path1, path2): Promise<[Path, Array<Path>, Array<Path>]> {
    const ancestors1: Array<Path> = path1.getAncestryPaths();
    const ancestors2: Array<Path> = path2.getAncestryPaths();
    const commonAncestry = _.takeWhile(
      _.zip(ancestors1, ancestors2),
      pair => (pair[0] && pair[1] && pair[0].is(pair[1]))
    );
    const common = _.last(commonAncestry)[0];
    const firstDifference = commonAncestry.length;
    return [common, ancestors1.slice(firstDifference), ancestors2.slice(firstDifference)];
  }

  // returns whether an row is actually reachable from the root node
  // if something is not detached, it will have a parent, but the parent wont mention it as a child
  public async isAttached(row) {
    return (await this.allAncestors(row, {inclusive: true})).indexOf(this.root.row) !== -1;
  }

  public async getSiblingBefore(path) {
    return await this.getSiblingOffset(path, -1);
  }

  public async getSiblingAfter(path) {
    return await this.getSiblingOffset(path, 1);
  }

  public async getSiblingOffset(path, offset) {
    return (await this.getSiblingRange(path, offset, offset, true))[0];
  }

  public async getSiblingRange(path, min_offset, max_offset, includeNull = false) {
    const index = await this.indexInParent(path);
    return this._getSlice(
      await this.getSiblings(path), min_offset + index, max_offset + index
    ).filter(x => includeNull || (x !== null));
  }

  public async getChildRange(path, min, max) {
    return (await this._getChildren(path.row, min, max)).map(function(child_row) {
      if (child_row === null) {
        return null;
      }
      return path.child(child_row);
    });
  }

  private async _newChild(parent, index = -1) {
    const row = await this.store.getNew();
    await this._attach(row, parent, index);
    return row;
  }

  public async newChild(path, index = -1) {
    const row = await this._newChild(path.row, index);
    return path.child(row);
  }

  private async allLines() {
    // TODO: deal with clones
    const paths = [];

    const helper = async (path) => {
      paths.push(path);
      await Promise.all(
        (await this.getChildren(path)).map(
          async (child) => await helper(child)
        )
      );
    };
    await helper(this.root);
    return paths;
  }

  public async search(query, options: SearchOptions = {}) {
    const { nresults = 10, case_sensitive = false } = options;
    const results = []; // list of (path, index) pairs

    if (query.length === 0) {
      return results;
    }

    const canonicalize = x => case_sensitive ? x : x.toLowerCase();
    const query_words =
      query.split(/\s/g).filter(x => x.length).map(canonicalize);

    const paths = await this.allLines();
    for (let i = 0; i < paths.length; i++) {
      const path = paths[i];
      const text = await this.getText(path.row);
      const line = canonicalize(text);
      const matches = [];
      if (_.every(query_words.map((word) => {
        const index = line.indexOf(word);
        if (index === -1) { return false; }
        for (let j = index; j < index + word.length; j++) {
          matches.push(j);
        }
        return true;
      }))) {
        results.push({ path, matches });
      }
      if (nresults > 0 && results.length === nresults) {
        break;
      }
    }
    return results;
  };

  // important: serialized automatically garbage collects
  public async serializeRow(row = this.root.row): Promise<SerializedLine> {
    const line = await this.getLine(row);
    const text = await this.getText(row);
    const struct: SerializedLine = {
      text,
    };

    constants.text_properties.forEach((property) => {
      if (_.some(line.map(obj => obj[property]))) {
        struct[property] = line.map(obj => obj[property] ? '.' : ' ').join('');
      }
    });
    if (await this.collapsed(row)) {
      struct.collapsed = true;
    }
    const plugins = await this.applyHookAsync('serializeRow', {}, {row});
    if (Object.keys(plugins).length > 0) {
      struct.plugins = plugins;
    }

    return struct;
  }

  public async getViewContents(path = this.root, isFirst = false) {

    const [ collapsed, children ] = await Promise.all([
      this.collapsed(path.row),
      this._getChildren(path.row),
    ]);

    let childProm = Promise.resolve(null);
    if (isFirst || !collapsed) {
      childProm = Promise.all(
        children.map(
          async (child) => await this.getViewContents(path.child(child))
        )
      );
    }

    const [ pluginContents, childrenContents, line, isClone ] = await Promise.all([
      this.applyHookAsync('pluginPathContents', {}, { path }),
      childProm,
      this.getLine(path.row),
      this.isClone(path.row),
    ]);

    return {
      path: path,
      line: line,
      collapsed: collapsed,
      isClone: isClone,
      plugins: pluginContents,
      hasChildren: children.length > 0,
      children: childrenContents,
    };
  }

  public async serialize(
    row = this.root.row,
    options: {pretty?: boolean} = {},
    serialized = {}
  ) {
    if (row in serialized) {
      const struct = serialized[row];
      struct.id = row;
      return { clone: row };
    }

    const struct: any = await this.serializeRow(row);
    // NOTE: this must be done in order due to cloning
    // const children = await Promise.all((await this._getChildren(row)).map(
    //   async (childrow) => await this.serialize(childrow, options, serialized)
    // ));
    const childRows = await this._getChildren(row);
    let children = [];
    for (let i = 0; i < childRows.length; i++) {
      children.push(
        await this.serialize(childRows[i], options, serialized)
      );
    }
    if (children.length) {
      struct.children = children;
    }

    serialized[row] = struct;

    if (options.pretty) {
      if ((children.length === 0) &&
          (!await this.isClone(row)) &&
          _.every(
            Object.keys(struct),
            key => (key === 'children' || key === 'text' || key === 'collapsed')
          )
         ) {
        return struct.text;
      }
    }
    return struct;
  }

  public async loadTo(
    serialized, parent_path = this.root, index = -1,
    id_mapping = {}, replace_empty = false
  ) {
    if (serialized.clone) {
      // NOTE: this assumes we load in the same order we serialize
      errors.assert(serialized.clone in id_mapping);
      const row = id_mapping[serialized.clone];
      const path = parent_path.child(row);
      await this.attachChild(parent_path, path, index);
      return path;
    }

    const children = await this.getChildren(parent_path);
    // if parent_path has only one child and it's empty, delete it
    let path;
    if (replace_empty && children.length === 1 &&
        ((await this.getLine(children[0].row)).length === 0)) {
      path = children[0];
    } else {
      path = await this.newChild(parent_path, index);
    }

    if (typeof serialized === 'string') {
      await this.setLine(path.row, serialized.split(''));
    } else {
      if (serialized.id) {
        id_mapping[serialized.id] = path.row;
      }
      const line = serialized.text.split('').map(char => ({char}));
      constants.text_properties.forEach((property) => {
        if (serialized[property]) {
          for (const i in serialized[property]) {
            const val = serialized[property][i];
            if (val === '.') {
              line[i][property] = true;
            }
          }
        }
      });

      await this.setLine(path.row, line);
      await this.store.setCollapsed(path.row, serialized.collapsed);

      if (serialized.children) {
        for (let i = 0; i < serialized.children.length; i++) {
          const serialized_child = serialized.children[i];
          await this.loadTo(serialized_child, path, -1, id_mapping);
        }
      }
    }

    await this.emitAsync('loadRow', path, serialized.plugins || {});

    return path;
  }

  public async load(serialized_rows) {
    const id_mapping = {};
    for (let i = 0; i < serialized_rows.length; i++) {
      const serialized_row = serialized_rows[i];
      await this.loadTo(serialized_row, this.root, -1, id_mapping, true);
    }
  }
}
