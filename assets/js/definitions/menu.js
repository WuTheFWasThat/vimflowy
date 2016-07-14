import _ from 'lodash';

import Menu from '../menu.coffee';
import Modes from '../modes.coffee';
import keyDefinitions from '../keyDefinitions.coffee';

const MODES = Modes.modes;

let CMD_SEARCH = keyDefinitions.registerCommand({
  name: 'SEARCH',
  default_hotkeys: {
    normal_like: ['/', 'ctrl+f']
  }
}
);
keyDefinitions.registerAction([MODES.NORMAL], CMD_SEARCH, {
  description: 'Search',
}, function() {
  this.session.setMode(MODES.SEARCH);
  return this.session.menu = new Menu(this.session.menuDiv, chars => {
    let find = function(document, query, options = {}) {
      let nresults = options.nresults || 10;
      let { case_sensitive } = options;

      let results = []; // list of (path, index) pairs

      let canonicalize = x => options.case_sensitive ? x : x.toLowerCase();

      let get_words = char_array =>
        (char_array.join(''))
          .split(/\s/g)
          .filter(x => x.length)
          .map(canonicalize)
      ;

      let query_words = get_words(query);
      if (query.length === 0) {
        return results;
      }

      let iterable = document.orderedLines();
      for (let i = 0; i < iterable.length; i++) {
        let path = iterable[i];
        let line = canonicalize((document.getText(path.row)).join(''));
        let matches = [];
        if (_.every(query_words.map((function(word) {
          i = line.indexOf(word);
          if (i === -1) { return false; }
          matches = matches.concat(__range__(i, i+word.length, false));
          return true;
        })
        ))) {
          results.push({ path, matches });
        }
        if (nresults > 0 && results.length === nresults) {
          break;
        }
      }
      return results;
    };

    return _.map(
      (find(this.session.document, chars)),
      found => {
        let { path } = found;
        let highlights = {};
        for (let j = 0; j < found.matches.length; j++) {
          let i = found.matches[j];
          highlights[i] = true;
        }
        return {
          contents: this.session.document.getLine(path.row),
          renderOptions: { highlights },
          fn: () => {
            this.session.zoomInto(path);
            return this.session.cursor.setPath(path);
          }
        };
      }
    );
  }
  );
}
);

let CMD_MENU_SELECT = keyDefinitions.registerCommand({
  name: 'MENU_SELECT',
  default_hotkeys: {
    insert_like: ['enter']
  }
}
);
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_SELECT, {
  description: 'Select current menu selection',
}, function() {
  this.session.menu.select();
  return this.session.setMode(MODES.NORMAL);
}
);

let CMD_MENU_UP = keyDefinitions.registerCommand({
  name: 'MENU_UP',
  default_hotkeys: {
    insert_like: ['ctrl+k', 'up', 'tab']
  }
}
);
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_UP, {
  description: 'Select previous menu selection',
}, function() {
  return this.session.menu.up();
}
);

let CMD_MENU_DOWN = keyDefinitions.registerCommand({
  name: 'MENU_DOWN',
  default_hotkeys: {
    insert_like: ['ctrl+j', 'down', 'shift+tab']
  }
}
);
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_DOWN, {
  description: 'Select next menu selection',
}, function() {
  return this.session.menu.down();
}
);

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}