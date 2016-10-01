// tslint:disable:align

import Menu from '../menu';
import * as Modes from '../modes';
import keyDefinitions from '../keyDefinitions';

const MODES = Modes.modes;

const CMD_SEARCH = keyDefinitions.registerCommand({
  name: 'SEARCH',
  default_hotkeys: {
    normal_like: ['/', 'ctrl+f'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_SEARCH, {
  description: 'Search',
}, async function() {
  await this.session.setMode(MODES.SEARCH);
  this.session.menu = new Menu(async (text) => {
    return (await this.session.document.search(text))
      .map(({ path, matches }) => {
        const highlights = {};
        matches.forEach((i) => {
          highlights[i] = true;
        });
        return {
          contents: this.session.document.getLine(path.row),
          renderOptions: { highlights },
          fn: async () => {
            await this.session.zoomInto(path);
            await this.session.cursor.setPath(path);
          },
        };
      });
  });
});

const CMD_MENU_SELECT = keyDefinitions.registerCommand({
  name: 'MENU_SELECT',
  default_hotkeys: {
    insert_like: ['enter'],
  },
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
    insert_like: ['ctrl+k', 'up', 'tab'],
  },
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_UP, {
  description: 'Select previous menu selection',
}, async function() {
  return this.session.menu.up();
});

const CMD_MENU_DOWN = keyDefinitions.registerCommand({
  name: 'MENU_DOWN',
  default_hotkeys: {
    insert_like: ['ctrl+j', 'down', 'shift+tab'],
  },
});
keyDefinitions.registerAction([MODES.SEARCH], CMD_MENU_DOWN, {
  description: 'Select next menu selection',
}, async function() {
  return this.session.menu.down();
});

