import * as _ from 'lodash';
import 'core-js/shim';

import * as errors from '../../shared/utils/errors';
import EventEmitter from './utils/eventEmitter';
import * as fn_utils from './utils/functional';
// import logger from './utils/logger';
import { isWhitespace } from './utils/text';
import Path from './path';
import { DocumentStore } from './datastore';
import { InMemory } from '../../shared/data_backend';
import {
  Row, Col, Char, Line, SerializedLine, SerializedBlock
} from './types';

type RowInfo = {
  readonly line: Line;
  readonly collapsed: boolean;
  // TODO use Immutable.List?
  readonly parentRows: Array<Row>;
  readonly childRows: Array<Row>;
  readonly pluginData: any;
};

export type AttachedChildInfo = {
  parent_row: Row,
  parent_index: number,
  row: Row,
  child_index: number,
};

/*
 * Immutable representation of what we know about a row,
 * including all descendants (recursively) by reference.
 * Child is null, if we haven't loaded it yet
 */
// TODO: rename this to cached Tree?
export class CachedRowInfo {
  public readonly row: Row;
  public readonly info: RowInfo;
  // TODO: use immutable list?
  public readonly children: Array<CachedRowInfo | null>;

  constructor(
    row: Row,
    info: RowInfo,
    children: Array<CachedRowInfo | null>,
  ) {
    this.row = row;
    this.info = info;
    this.children = children;
  }

  public clone() {
    return new CachedRowInfo(
      this.row, this.info, this.children
    );
  }

  public get parentRows() {
    return this.info.parentRows;
  }
  public get childRows() {
    return this.info.childRows;
  }
  public get line() {
    return this.info.line;
  }
  public get collapsed() {
    return this.info.collapsed;
  }
  public get pluginData() {
    return this.info.pluginData;
  }

  public setChildren(children: Array<CachedRowInfo | null>): CachedRowInfo {
    return new CachedRowInfo(this.row, this.info, children);
  }
  private setInfo(info: RowInfo): CachedRowInfo {
    return new CachedRowInfo(this.row, info, this.children);
  }
  public setLine(line: Line): CachedRowInfo {
    const info: RowInfo = Object.assign({}, this.info, { line });
    return this.setInfo(info);
  }
  public setCollapsed(collapsed: boolean): CachedRowInfo {
    const info: RowInfo = Object.assign({}, this.info, { collapsed });
    return this.setInfo(info);
  }
  public setChildRows(childRows: Array<Row>): CachedRowInfo {
    const info: RowInfo = Object.assign({}, this.info, { childRows });
    return this.setInfo(info);
  }
  public setParentRows(parentRows: Array<Row>): CachedRowInfo {
    const info: RowInfo = Object.assign({}, this.info, { parentRows });
    return this.setInfo(info);
  }
  public setPluginData(pluginData: any): CachedRowInfo {
    const info: RowInfo = Object.assign({}, this.info, { pluginData });
    return this.setInfo(info);
  }
}

class DocumentCache {
  private cache: {[row: number]: CachedRowInfo};

  constructor() {
    this.cache = {};
  }

  public clear() {
    this.cache = {};
  }

  public loadRow(row: Row, info: RowInfo) {
    const cached = new CachedRowInfo(row, info, info.childRows.map((childRow) => {
      return this.get(childRow);
    }));
    this.set(row, cached);
    return cached;
  }

  public isCached(row: Row) {
    return !!this.get(row);
  }

  /*
   * Updates childRows for a given row
   * Call this function if a row changed
   */
  private bubbleUpdate(row: Row) {
    const cachedRow = this.get(row);
    if (!cachedRow) {
      return;
    }
    cachedRow.parentRows.forEach((parentRow) => {
      const parentCachedRow = this.get(parentRow);
      if (!parentCachedRow) {
        return;
      }
      // NOTE: this will cause more bubbled updates
      this.set(parentRow, this.updateChildren(parentCachedRow));
    });
  }

  private set(row: Row, cachedRow: CachedRowInfo) {
    this.cache[row] = cachedRow;
    this.bubbleUpdate(row);
  }

  private update(row: Row, updateFn: (info: CachedRowInfo) => CachedRowInfo, force?: boolean) {
    const cachedRow = this.get(row);
    if (!cachedRow) {
      if (force) {
        throw new Error(`Updating failed - Row ${row} was not cached`);
      }
      return false;
    }
    this.set(row, updateFn(cachedRow));
    return true;
  }

  public get(row: Row) {
    const cachedRow = this.cache[row];
    if (!cachedRow) {
      return null;
    }
    return cachedRow;
  }

  private updateChildren(cachedRow: CachedRowInfo) {
    return cachedRow.setChildren(
      cachedRow.childRows.map((childRow) => this.get(childRow))
    );
  }

  public setLine(row: Row, line: Line) {
    this.update(row, (cachedRow) => cachedRow.setLine(line), true);
  }
  public setCollapsed(row: Row, collapsed: boolean) {
    this.update(row, (cachedRow) => cachedRow.setCollapsed(collapsed), true);
  }
  public setChildRows(row: Row, childRows: Array<Row>) {
    this.update(row, (cachedRow) =>
      this.updateChildren(cachedRow.setChildRows(childRows))
    , true);
  }
  public setParentRows(row: Row, parentRows: Array<Row>) {
    this.update(row, (cachedRow) => cachedRow.setParentRows(parentRows), true);
  }
  public setPluginData(row: Row, pluginData: any) {
    this.update(row, (cachedRow) => cachedRow.setPluginData(pluginData), true);
  }
}

/*
Document is a wrapper class around the actual datastore, providing methods to manipulate the document
the document itself includes:
  - the text in each line, including text properties like bold/italic
  - the parent/child relationships and collapsed-ness of lines
also deals with loading the initial document from the datastore, and serializing the document to a string

Currently, the separation between the Session and Document classes is not very good.  (see session.ts)
*/

type SearchOptions = {nresults?: number, case_sensitive?: boolean};

export default class Document extends EventEmitter {
  public cache: DocumentCache;
  public store: DocumentStore;
  public name: string;
  public root: Path;

  constructor(store: DocumentStore, name = '') {
    super();
    this.cache = new DocumentCache();
    this.store = store;
    this.name = name;
    this.root = Path.root();
    return this;
  }


  public async _newChild(parent: Row, index = -1): Promise<AttachedChildInfo> {
    const row = await this.store.getNew();

    // NOTE: order is important for caching.
    // - first emit async so plugins can prepare for what will happen
    // - then load regular data (attach hooks can use cached plugin data)
    // - lastly update plugin data (plugin data knows attached state)

    await this.emitAsync('childAdded', { row, parent });

    // necessary only for speed reasons
    this.cache.loadRow(row, {
      line: [], collapsed: false,
      childRows: [], parentRows: [], // parent will get added
      pluginData: {},
    });

    const [ info ] = await Promise.all([
      this._attach(row, parent, index),
      // purely to populate the cache
      this.store.setDetachedParent(row, null),
    ]);

    await this.updateCachedPluginData(row);
    return info;
  }

  public async getInfo(row: Row): Promise<CachedRowInfo> {
    errors.assert(row != null, 'Cannot get info for undefined');
    const cached = this.cache.get(row);
    if (cached !== null) {
      return cached;
    }

    const [
      line, collapsed, children, parents, pluginData
    ] = await Promise.all<Line, boolean, Array<Row>, Array<Row>, any>([
      this.store.getLine(row),
      this.store.getCollapsed(row),
      this.store.getChildren(row),
      this.store.getParents(row),
      this.applyHookAsync('pluginRowContents', {}, { row }),
    ]);
    const info: RowInfo = {
      line, collapsed,
      parentRows: parents,
      childRows: children,
      pluginData,
    };
    return this.cache.loadRow(row, info);
  }

  public async forceLoadTree(row = this.root.row, ignoreCollapsed = false) {
    const cachedRow = await this.getInfo(row);

    if (ignoreCollapsed || !cachedRow.collapsed) {
      await Promise.all(
        cachedRow.childRows.map(
          async (childRow) => await this.forceLoadTree(childRow)
        )
      );
    }
  }

  // TODO: actually use this
  public async forceLoadPath(path: Path) {
    const ancestry = path.getAncestry();
    await Promise.all(
      ancestry.map(async (row) => {
        await this.getInfo(row);
      })
    );
  }

  public async updateCachedPluginData(row: Row) {
    if (this.cache.isCached(row)) {
      const pluginData = await this.applyHookAsync('pluginRowContents', {}, { row });
      this.cache.setPluginData(row, pluginData);
    } else {
      await this.getInfo(row);
    }
  }

  public async getLine(row: Row) {
    return (await this.getInfo(row)).line;
  }

  public async getText(row: Row) {
    return (await this.getLine(row)).join('');
  }

  public async getChar(row: Row, col: Col) {
    return (await this.getLine(row))[col];
  }

  public async setLine(row: Row, line: Line) {
    this.cache.setLine(row, line);
    await this.store.setLine(row, line);
  }

  // get word at this location
  // if on a whitespace character, return nothing
  public async getWord(row: Row, col: Col) {
    const text = await this.getLine(row);

    if (isWhitespace(text[col])) {
      return '';
    }

    let start = col;
    let end = col;
    while ((start > 0) && !isWhitespace(text[start - 1])) {
      start -= 1;
    }
    while ((end < text.length - 1) && !isWhitespace(text[end + 1])) {
      end += 1;
    }
    let word = text.slice(start, end + 1).join('');
    // remove leading and trailing punctuation
    word = word.replace(/^[-.,()&$#!\[\]{}"']+/g, '');
    word = word.replace(/[-.,()&$#!\[\]{}"']+$/g, '');
    return word;
  }

  public async writeChars(row: Row, col: Col, chars: Array<Char>) {
    const line = (await this.getLine(row)).slice();
    line.splice(col, 0, ...chars);
    return await this.setLine(row, line);
  }

  public async deleteChars(row: Row, col: Col, num: number): Promise<Line> {
    const line = await this.getLine(row);
    const deleted = line.splice(col, num);
    await this.setLine(row, line);
    return deleted;
  }

  public async getLength(row: Row) {
    return (await this.getLine(row)).length;
  }

  // structure

  public async _getChildren(row: Row, min = 0, max = -1): Promise<Array<Row>> {
    const info = await this.getInfo(row);
    return fn_utils.getSlice(info.childRows, min, max);
  }

  private async _setChildren(row: Row, children: Array<Row>) {
    this.cache.setChildRows(row, children);
    return await this.store.setChildren(row, children);
  }


  private async _getParents(row: Row): Promise<Array<Row>> {
    const info = await this.getInfo(row);
    return info.parentRows;
  }

  private async _setParents(row: Row, parent_rows: Array<Row>) {
    this.cache.setParentRows(row, parent_rows);
    return await this.store.setParents(row, parent_rows);
  }

  public async getChildren(parent_path: Path): Promise<Array<Path>> {
    return (await this._getChildren(parent_path.row)).map(row => parent_path.child(row));
  }

  public async hasChildren(row: Row) {
    return (await this._getChildren(row)).length > 0;
  }

  public async hasChild(parent_row: Row, row: Row): Promise<boolean> {
    return (await this._getChildren(parent_row)).indexOf(row) !== -1;
  }

  public async getSiblings(path: Path) {
    if (path.parent == null) { // i.e. (path.isRoot())
      return [path];
    }
    return await this.getChildren(path.parent);
  }

  public async nextClone(path: Path): Promise<Path> {
    if (path.parent == null) {
      return path;
    }
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

  public async indexInParent(child: Path) {
    const children = await this.getSiblings(child);
    return _.findIndex(children, sib => sib.row === child.row);
  }

  public async collapsed(row: Row) {
    return (await this.getInfo(row)).collapsed;
  }

  public async setCollapsed(row: Row, collapsed: boolean) {
    this.cache.setCollapsed(row, collapsed);
    await this.store.setCollapsed(row, collapsed);
  }

  public async toggleCollapsed(row: Row) {
    this.setCollapsed(row, !await this.collapsed(row));
  }

  // last thing visible nested within row
  public async walkToLastVisible(row: Row, pathsofar: Array<Row> = []): Promise<Array<Row>> {
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
  public async isClone(row: Row) {
    const parents = await this._getParents(row);
    if (parents.length < 2) { // for efficiency reasons
      return false;
    }
    const attachedParents = await fn_utils.asyncFilter(
      parents, async (parent) => await this.isAttached(parent));
    return attachedParents.length > 1;
  }

  // Figure out which is the canonical one. Right now this is really 'arbitraryInstance'
  // NOTE: this is not very efficient, in the worst case, but probably doesn't matter
  public async canonicalPath(row: Row): Promise<Path | null> {
    errors.assert(row !== null, 'Empty row passed to canonicalPath');
    if (row === Path.rootRow()) {
      return this.root;
    }
    const parents = await this._getParents(row);
    for (let i = 0; i < parents.length; i++) {
      const parentRow = parents[i];
      const canonicalParent = await this.canonicalPath(parentRow);
      if (canonicalParent !== null) {
        return canonicalParent.child(row);
      }
    }
    return null;
  }

  // Return all ancestor rows, topologically sorted (root is *last*).
  // Excludes 'row' itself unless options.inclusive is specified
  // NOTE: includes possibly detached nodes
  public async allAncestors(
    row: Row,
    { inclusive = false }: { inclusive?: boolean } = { }
  ) {
    const visited: {[row: number]: boolean} = {};
    const ancestors: Array<Row> = []; // 'visited' with preserved insert order
    if (inclusive) {
      ancestors.push(row);
    }
    const visit = async (n: Row) => { // DFS
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

  public async _hasChild(parent_row: Row, row: Row) {
    const children = await this._getChildren(parent_row);
    const ci = _.findIndex(children, sib => sib === row);
    return ci !== -1;
  }

  private async _removeChild(parent_row: Row, row: Row) {
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
      parent_row,
      parent_index: pi,
      row,
      child_index: ci,
    };
    this.emit('childRemoved', info);
    return info;
  }

  private async _addChild(parent_row: Row, row: Row, index: number): Promise<AttachedChildInfo> {
    const children = await this._getChildren(parent_row);
    errors.assert(index <= children.length);
    if (index === -1) {
      index = children.length;
    }
    children.splice(index, 0, row);
    await this._setChildren(parent_row, children);

    const parents = await this._getParents(row);
    parents.push(parent_row);
    await this._setParents(row, parents);
    const info = {
      parent_row,
      parent_index: parents.length - 1,
      row,
      child_index: index,
    };
    return info;
  }

  public async _detach(row: Row, parent_row: Row) {
    const wasLast = !(await this.isClone(row));

    await this.emitAsync('beforeDetach', { row, parent_row, last: wasLast });
    const info = await this._removeChild(parent_row, row);
    if (wasLast) {
      await this.store.setDetachedParent(row, parent_row);
    }
    await this.emitAsync('afterDetach', { row, parent_row, last: wasLast });
    return info;
  }

  public async _attach(child_row: Row, parent_row: Row, index = -1): Promise<AttachedChildInfo> {
    const isFirst = (await this._getParents(child_row)).length === 0;
    await this.emitAsync('beforeAttach', { row: child_row, parent_row, first: isFirst});
    const info = await this._addChild(parent_row, child_row, index);
    const old_detached_parent = await this.store.getDetachedParent(child_row);
    if (old_detached_parent !== null) {
      errors.assert(isFirst);
      await this.store.setDetachedParent(child_row, null);
    }
    await this.emitAsync('afterAttach', { row: child_row, parent_row, first: isFirst, old_detached_parent});
    return info;
  }

  public async _move(child_row: Row, old_parent_row: Row, new_parent_row: Row, index = -1) {
    await this.emitAsync('beforeMove', {
      row: child_row, old_parent: old_parent_row, new_parent: new_parent_row,
    });

    const remove_info = await this._removeChild(old_parent_row, child_row);
    if ((old_parent_row === new_parent_row) && (index > remove_info.child_index)) {
      index = index - 1;
    }
    const add_info = await this._addChild(new_parent_row, child_row, index);

    await this.emitAsync('afterMove', {
      row: child_row, old_parent: old_parent_row, new_parent: new_parent_row,
    });

    return {
      old: remove_info,
      new: add_info,
    };
  }

  // attaches a detached child to a parent
  // the child should not have a parent already
  public async attachChild(parent: Path, child: Path, index = -1): Promise<Path> {
    return (await this.attachChildren(parent, [child], index))[0];
  }

  public async attachChildren(parent: Path, new_children: Array<Path>, index = -1): Promise<Array<Path>> {
    await this._attachChildren(parent.row, new_children.map(x => x.row), index);
    // for child in new_children
    //   child.setParent parent
    return new_children;
  }

  public async _attachChildren(parent: Row, new_children: Array<Row>, index = -1) {
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
  public async getCommonAncestor(path1: Path, path2: Path): Promise<[Path, Array<Path>, Array<Path>]> {
    const ancestors1: Array<Path> = path1.getAncestryPaths();
    const ancestors2: Array<Path> = path2.getAncestryPaths();

    const commonAncestry = _.takeWhile(
      _.zip(ancestors1, ancestors2),
      (pair: any) => (pair[0] && pair[1] && pair[0].is(pair[1]))
    ).map((pair) => pair[0]);

    const lastCommon = _.last(commonAncestry);
    if (lastCommon == null) {
        throw new Error(`No common ancestor found between ${path1} and ${path2}`);
    }
    const firstDifference = commonAncestry.length;
    return [lastCommon, ancestors1.slice(firstDifference), ancestors2.slice(firstDifference)];
  }

  // returns whether an row is actually reachable from the root node
  // if something is not detached, it will have a parent, but the parent wont mention it as a child
  public async isAttached(row: Row) {
    return (await this.allAncestors(row, {inclusive: true})).indexOf(this.root.row) !== -1;
  }

  public async isValidPath(path: Path) {
    let parent_row: Row = 0;
    const ancestry = path.getAncestry();
    for (let i = 0; i < ancestry.length; i++) {
      const row = ancestry[i];
      if (!await this.hasChild(parent_row, row)) {
        return false;
      }
      parent_row = row;
    }
    return true;
  }

  public async getSiblingBefore(path: Path) {
    return await this.getSiblingOffset(path, -1);
  }

  public async getSiblingAfter(path: Path) {
    return await this.getSiblingOffset(path, 1);
  }

  public async getSiblingOffset(path: Path, offset: number) {
    const arr = await this.getSiblingRange(path, offset, offset);
    if (!arr.length) {
      return null;
    }
    return arr[0];
  }

  public async getSiblingRange(path: Path, min_offset: number, max_offset: number) {
    const [ index, siblings ] = await Promise.all([
      this.indexInParent(path),
      this.getSiblings(path),
    ]);
    if (index + max_offset < 0) { return []; }
    const arr = fn_utils.getSlice(
      siblings,
      Math.max(index + min_offset, 0),
      index + max_offset,
    );
    return arr;
  }

  public async getChildRange(path: Path, min: number, max: number): Promise<Array<Path>> {
    return (await this._getChildren(path.row, min, max)).map(function(child_row) {
      return path.child(child_row);
    });
  }

  public async newChild(path: Path, index = -1) {
    const { row } = await this._newChild(path.row, index);
    return path.child(row);
  }

  private async* traverseSubtree(root: Path): AsyncIterableIterator<Path> {
    const visited_rows: {[row: number]: boolean} = {};
    let that = this;

    async function* helper(path: Path): AsyncIterableIterator<Path> {
      if (path.row in visited_rows) {
        return;
      }
      visited_rows[path.row] = true;
      yield path;
      const children = await that.getChildren(path);
      for (let i = 0; i < children.length; i++) {
        yield* await helper(children[i]);
      }
    }
    yield* await helper(root);
  }

  public async search(root: Path, query: string, options: SearchOptions = {}) {
    const { nresults = 10, case_sensitive = false } = options;
    const results: Array<{
      path: Path,
      matches: Array<number>,
    }> = []; // list of (path, index) pairs

    if (query.length === 0) {
      return results;
    }

    const canonicalize = (x: string) => case_sensitive ? x : x.toLowerCase();
    const query_words =
      query.split(/\s/g).filter(x => x.length).map(canonicalize);

    const paths = this.traverseSubtree(root);
    for await (let path of paths) {
      const text = await this.getText(path.row);
      const line = canonicalize(text);
      const matches: Array<number> = [];
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
  }

  // important: serialized automatically garbage collects
  public async serializeRow(row = this.root.row): Promise<SerializedLine> {
    const text = await this.getText(row);

    const struct: SerializedLine = {
      text,
    };
    if (await this.collapsed(row)) {
      struct.collapsed = true;
    }
    const plugins = await this.applyHookAsync('serializeRow', {}, {row});
    if (Object.keys(plugins).length > 0) {
      struct.plugins = plugins;
    }

    return struct;
  }

  public async serialize(
    row = this.root.row,
    options: {pretty?: boolean} = {},
    serialized: {[row: number]: SerializedBlock} = {}
  ): Promise<SerializedBlock> {
    if (row in serialized) {
      const clone_struct: any = serialized[row];
      clone_struct.id = row;
      return { clone: row };
    }

    const struct: any = await this.serializeRow(row);
    // NOTE: this must be done in order due to cloning
    // const children = await Promise.all((await this._getChildren(row)).map(
    //   async (childrow) => await this.serialize(childrow, options, serialized)
    // ));
    const childRows = await this._getChildren(row);
    let children: Array<any> = [];
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
          (!struct.plugins)
         ) {
        return struct.text;
      }
    }
    return struct;
  }

  public async loadTo(
    // TODO: serialized is a SerializedBlock
    serialized: any, parent_path = this.root, index = -1,
    id_mapping: {[key: number]: Row} = {}, replace_empty = false
  ) {
    if (serialized.clone) {
      // NOTE: this assumes we load in the same order we serialize
      errors.assert(serialized.clone in id_mapping);
      const row = id_mapping[serialized.clone];
      const clone_path = parent_path.child(row);
      await this.attachChild(parent_path, clone_path, index);
      return clone_path;
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
      const line = serialized.text.split('');

      await Promise.all([
        this.setLine(path.row, line),
        this.setCollapsed(path.row, serialized.collapsed),
      ]);

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

  public async load(serialized_rows: Array<SerializedBlock>) {
    const id_mapping = {};
    for (let i = 0; i < serialized_rows.length; i++) {
      const serialized_row = serialized_rows[i];
      await this.loadTo(serialized_row, this.root, -1, id_mapping, true);
    }
  }

  public async loadEmpty() {
    await this.load(['']);
  }
}

export class InMemoryDocument extends Document {
  constructor() {
    super(new DocumentStore(new InMemory()));
  }
}
