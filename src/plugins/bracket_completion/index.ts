import { registerPlugin } from '../../assets/ts/plugins';
import { Char } from '../../assets/ts/types';

const completions: { [key: string]: Char } = {'(': ')', '{': '}', '[': ']', '"': '"'};

registerPlugin({
  name: 'Bracket Completion',
  version: 1,
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
},
  (api => api.deregisterAll()),
);
