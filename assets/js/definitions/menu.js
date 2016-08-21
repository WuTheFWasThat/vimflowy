import _ from 'lodash';

import Menu from '../menu';
import * as Modes from '../modes';
import keyDefinitions from '../keyDefinitions';

const MODES = Modes.modes;

const CMD_SEARCH = keyDefinitions.registerCommand({
  name: 'SEARCH',
  default_hotkeys: {
    normal_like: ['/', 'ctrl+f']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_SEARCH, {
  description: 'Search',
}, async function() {
  await this.session.setMode(MODES.SEARCH);
  return this.session.menu = new Menu(this.session.menuDiv, chars => {
    const find = function(document, query, options = {}) {
      const nresults = options.nresults || 10;

      const results = []; // list of (path, index) pairs

      const canonicalize = x => options.case_sensitive ? x : x.toLowerCase();

      const get_words = char_array =>
        char_array.join('')
          .split(/\s/g)
          .filter(x => x.length)
          .map(canonicalize)
      ;

      const query_words = get_words(query);
      if (query.length === 0) {
        return results;
      }

      const paths = document.orderedLines();
      for (let i = 0; i < paths.length; i++) {
        const path = paths[i];
        const line = canonicalize(document.getText(path.row).join(''));
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

    return _.map(
      find(this.session.document, chars),
      found => {
        const path = found.path;
        const highlights = {};
        found.matches.forEach((i) => {
          highlights[i] = true;
        });
        return {
          contents: this.session.document.getLine(path.row),
          renderOptions: { highlights },
          fn: async () => {
            await this.session.zoomInto(path);
            await this.session.cursor.setPath(path);
          }
        };
      });
  });
});

const CMD_MENU_SELECT = keyDefinitions.registerCommand({
  name: 'MENU_SELECT',
  default_hotkeys: {
    insert_like: ['enter']
  }
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_SELECT, {
  description: 'Select current menu selection',
}, async function() {
  await this.session.menu.select();
  return await this.session.setMode(MODES.NORMAL);
});

const CMD_MENU_UP = keyDefinitions.registerCommand({
  name: 'MENU_UP',
  default_hotkeys: {
    insert_like: ['ctrl+k', 'up', 'tab']
  }
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_UP, {
  description: 'Select previous menu selection',
}, async function() {
  return this.session.menu.up();
});

const CMD_MENU_DOWN = keyDefinitions.registerCommand({
  name: 'MENU_DOWN',
  default_hotkeys: {
    insert_like: ['ctrl+j', 'down', 'shift+tab']
  }
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_DOWN, {
  description: 'Select next menu selection',
}, async function() {
  return this.session.menu.down();
});

