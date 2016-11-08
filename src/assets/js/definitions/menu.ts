import Menu from '../menu';
import keyDefinitions, { Action } from '../keyDefinitions';

keyDefinitions.registerAction(new Action(
  'search',
  'Search',
  async function({ session }) {
    await session.setMode('SEARCH');
    session.menu = new Menu(async (text) => {
      const results = await session.document.search(text);
      return Promise.all(
        results.map(async ({ path, matches }) => {
          const highlights = {};
          matches.forEach((i) => {
            highlights[i] = true;
          });
          return {
            contents: await session.document.getLine(path.row),
            renderOptions: { highlights },
            fn: async () => {
              await session.zoomInto(path);
              await session.cursor.setPath(path);
            },
          };
        })
      );
    });
  },
));

keyDefinitions.registerAction(new Action(
  'move-cursor-search',
  'Move the cursor',
  async function({ motion, session }) {
    if (motion == null) {
      throw new Error('Motion command was not passed a motion');
    }
    await motion(session.menu.session.cursor, {pastEnd: true});
  },
));

keyDefinitions.registerAction(new Action(
  'search-delete-char-after',
  'Delete character after the cursor (i.e. del key)',
  async function({ session }) {
    await session.menu.session.delCharsAfterCursor(1);
  },
));

keyDefinitions.registerAction(new Action(
  'search-delete-char-before',
  'Delete previous character (i.e. backspace key)',
  async function({ session }) {
    await session.menu.session.deleteAtCursor();
  },
));

keyDefinitions.registerAction(new Action(
  'search-select',
  'Select current menu selection',
  async function({ session }) {
    await session.menu.select();
    return await session.setMode('NORMAL');
  },
));

keyDefinitions.registerAction(new Action(
  'search-up',
  'Select previous menu selection',
  async function({ session }) {
    return session.menu.up();
  },
));

keyDefinitions.registerAction(new Action(
  'search-down',
  'Select next menu selection',
  async function({ session }) {
    return session.menu.down();
  },
));

