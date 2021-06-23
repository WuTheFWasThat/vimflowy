import { registerPlugin } from '../../assets/ts/plugins';
import { Char } from '../../assets/ts/types';

const completions: { [key: string]: Char } = {'(': ')', '{': '}', '[': ']', '"': '"'};

registerPlugin({
  name: 'Bracket Completion',
  version: 2,
  author: 'Victor Tao',
  description: `
    Auto completes ${Object.keys(completions).join(', ')} in insert mode
  `,
}, function (api) {
  api.registerHook('session', 'charInserted', async (_struct, { key }) => {
    if (key in completions) {
      await api.session.addCharsAtCursor([completions[key]]);
      await api.session.cursor.left();
    }
  });
  api.registerHook('session', 'deleteCharAfter', async (_struct, {}) => {
    const col = api.session.cursor.col;
    const line = await api.session.curLine();
    if (col + 1 < line.length && line[col] in completions) {
      if (line[col + 1] === completions[line[col]]) {
        await api.session.delCharsAfterCursor(1);
      }
    }
  });
  api.registerHook('session', 'deleteCharBefore', async (_struct, {}) => {
    const col = api.session.cursor.col;
    const line = await api.session.curLine();
    if (col > 0 && line[col - 1] in completions) {
      if (line[col] === completions[line[col - 1]]) {
        await api.session.delCharsAfterCursor(1);
      }
    }
  });
},
  (api => api.deregisterAll()),
);
