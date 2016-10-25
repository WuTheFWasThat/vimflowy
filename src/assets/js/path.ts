import * as errors from './errors';

import { Row, SerializedPath } from './types';

// represents a tree-traversal starting from the root going down
// should be immutable
export default class Path {
  public parent: Path;
  public row: Row;

  public static rootRow(): Row {
    return 0;
  }

  public static root() {
    return new Path(null, Path.rootRow());
  }

  public static loadFromAncestry(ancestry: SerializedPath) {
    if (ancestry.length === 0) {
      return Path.root();
    }
    const row = ancestry.pop();
    const parent = Path.loadFromAncestry(ancestry);
    return parent.child(row);
  }

  constructor(parent, row) {
    this.parent = parent;
    this.row = row;
  }

  public isRoot() {
    return this.row === Path.rootRow();
  }

  // gets a list of IDs
  public getAncestry(): SerializedPath {
    if (this.isRoot()) { return []; }
    const ancestors = this.parent.getAncestry();
    ancestors.push(this.row);
    return ancestors;
  }

  // returns an array representing the ancestry of a row,
  // up until the ancestor specified by the `stop` parameter
  // i.e. [stop, stop's child, ... , row's parent , row]
  public getAncestryPaths(stop?): Array<Path> {
    if (!stop) {
      stop = Path.root();
    }
    const ancestors: Array<Path> = [];
    let path: Path = this;
    while (!path.is(stop)) {
      errors.assert(!path.isRoot(), `Failed to get ancestry for ${this} going up until ${stop}`);
      ancestors.push(path);
      path = path.parent;
    }
    ancestors.push(stop);
    ancestors.reverse();
    return ancestors;
  }

  // length() {
  //   if this.parent === null {
  //     return 0;
  //   }
  //   return 1 + this.parent.length();
  // }

  public child(row) {
    errors.assert(row !== this.row);
    return new Path(this, row);
  }

  public isDescendant(other_path) {
    return this.walkFrom(other_path) !== null;
  }

  public walkFrom(ancestor) {
    const my_ancestry = this.getAncestry();
    const their_ancestry = ancestor.getAncestry();
    if (my_ancestry.length < their_ancestry.length) {
      return null;
    }
    for (let i = 0; i < their_ancestry.length; i++) {
      if (my_ancestry[i] !== their_ancestry[i]) {
        return null;
      }
    }
    return my_ancestry.slice(their_ancestry.length);
  }

  public shedUntil(row): [Array<Row>, Path] | null {
    let ancestor: Path = this;
    const path: Array<Row> = [];
    while (ancestor.row !== row) {
      if (!ancestor.parent) {
        return null;
      }
      path.push(ancestor.row);
      ancestor = ancestor.parent;
    }
    return [path.reverse(), ancestor];
  }

  public extend(walk) {
    let descendent: Path = this;
    walk.forEach((row) => {
      descendent = descendent.child(row);
    });
    return descendent;
  }

  // Represents the exact same row
  public is(other) {
    if (other === undefined) { return false; }
    if (this.row !== other.row) { return false; }
    if (this.isRoot()) { return other.isRoot(); }
    if (other.isRoot()) { return false; }
    return this.parent.is(other.parent);
  }
}
