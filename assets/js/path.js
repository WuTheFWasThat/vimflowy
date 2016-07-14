import constants from './constants.coffee';
import errors from './errors.coffee';

// represents a tree-traversal starting from the root going down
// should be immutable
class Path {
  constructor(parent, row) {
    this.parent = parent;
    this.row = row;
  }

  isRoot() {
    return this.row === constants.root_row;
  }

  // gets a list of IDs
  getAncestry() {
    if (this.isRoot()) { return []; }
    let ancestors = this.parent.getAncestry();
    ancestors.push(this.row);
    return ancestors;
  }

  // length: () ->
  //   if @parent == null
  //     return 0
  //   return 1 + (do @parent.length)

  child(row) {
    errors.assert((row !== this.row));
    return new Path(this, row);
  }

  isDescendant(other_path) {
    return (this.walkFrom(other_path)) !== null;
  }

  walkFrom(ancestor) {
    let my_ancestry = this.getAncestry();
    let their_ancestry = ancestor.getAncestry();
    if (my_ancestry.length < their_ancestry.length) {
      return null;
    }
    let iterable = __range__(0, their_ancestry.length, false);
    for (let j = 0; j < iterable.length; j++) {
      let i = iterable[j];
      if (my_ancestry[i] !== their_ancestry[i]) {
        return null;
      }
    }
    return my_ancestry.slice(their_ancestry.length);
  }

  shedUntil(row) {
    let ancestor = this;
    let path = [];
    while (ancestor.row !== row) {
      if (!ancestor.parent) {
        return [null, null];
      }
      path.push(ancestor.row);
      ancestor = ancestor.parent;
    }
    return [path.reverse(), ancestor];
  }

  extend(walk) {
    let descendent = this;
    for (let i = 0; i < walk.length; i++) {
      let row = walk[i];
      descendent = descendent.child(row);
    }
    return descendent;
  }

  // Represents the exact same row
  is(other) {
    if (this.row !== other.row) { return false; }
    if (this.isRoot()) { return other.isRoot(); }
    if (other.isRoot()) { return false; }
    return this.parent.is(other.parent);
  }
}

Path.getRoot = () => new Path(null, constants.root_row);

Path.loadFromAncestry = function(ancestry) {
  if (ancestry.length === 0) {
    return Path.getRoot();
  }
  let row = ancestry.pop();
  let parent = Path.loadFromAncestry(ancestry);
  return parent.child(row);
};

export default Path;

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}