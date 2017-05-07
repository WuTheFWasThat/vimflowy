import * as errors from './utils/errors';

import { Row, SerializedPath } from './types';

// represents a tree-traversal starting from the root going down
// should be immutable
export default class Path {
  public readonly parent: Path | null;
  public readonly row: Row;

  public static rootRow(): Row {
    return 0;
  }

  public static root() {
    return new Path(null, Path.rootRow());
  }

  public static loadFromAncestry(ancestry: SerializedPath): Path {
    if (ancestry.length === 0) {
      return Path.root();
    }
    const row: Row = ancestry.pop() as Row;
    const parent = Path.loadFromAncestry(ancestry);
    return parent.child(row);
  }

  constructor(parent: Path | null, row: Row) {
    this.parent = parent;
    this.row = row;
  }

  public isRoot(): boolean {
    return this.row === Path.rootRow();
  }

  // gets a list of IDs
  public getAncestry(): SerializedPath {
    if (this.parent == null) { // i.e. (this.isRoot())
      return [];
    }
    const ancestors = this.parent.getAncestry();
    ancestors.push(this.row);
    return ancestors;
  }

  // returns an array representing the ancestry of a row,
  // up until the ancestor specified by the `stop` parameter
  // i.e. [stop, stop's child, ... , row's parent , row]
  public getAncestryPaths(stop: Path = Path.root()): Array<Path> {
    const ancestors: Array<Path> = [];
    let path: Path = this;
    while (!path.is(stop)) {
      if (path.parent == null) {
        throw new Error(`Failed to get ancestry for ${this} going up until ${stop}`);
      }
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

  public child(row: Row): Path {
    errors.assert(row !== this.row);
    return new Path(this, row);
  }

  public isDescendant(other_path: Path): boolean {
    return this.walkFrom(other_path) !== null;
  }

  public walkFrom(ancestor: Path): null | Array<Row> {
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

  public shedUntil(row: Row): [Array<Row>, Path] | null {
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

  public extend(walk: Array<Row>): Path {
    let descendent: Path = this;
    walk.forEach((row) => {
      descendent = descendent.child(row);
    });
    return descendent;
  }

  // Represents the exact same row
  public is(other: Path): boolean {
    if (other === undefined) { return false; }
    if (this.row !== other.row) { return false; }
    if (this.parent == null) { return other.parent == null; }
    if (other.parent == null) { return false; }
    return this.parent.is(other.parent);
  }
}
