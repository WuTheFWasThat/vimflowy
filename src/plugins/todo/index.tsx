import * as _ from 'lodash';

import './index.sass';

import { hideBorderAndModify, RegexTokenizerModifier } from '../../assets/js/utils/token_unfolder';
import { registerPlugin } from '../../assets/js/plugins';
import { matchWordRegex } from '../../assets/js/utils';
import { Row } from '../../assets/js/types';
import Session from '../../assets/js/session';

const strikethroughClass = 'strikethrough';

export const pluginName = 'Todo';

registerPlugin<void>(
  {
    name: pluginName,
    author: 'Jeff Wu',
    description: `Lets you strike out bullets (by default with ctrl+enter)`,
  },
  function(api) {
    api.registerHook('session', 'renderLineTokenHook', (tokenizer, hooksInfo) => {
      if (hooksInfo.has_cursor) {
        return tokenizer;
      }
      if (hooksInfo.has_highlight) {
        return tokenizer;
      }
      return tokenizer.then(RegexTokenizerModifier<React.ReactNode>(
        matchWordRegex('\\~\\~(\\n|.)+?\\~\\~'),
        hideBorderAndModify(2, 2, (char_info) => { char_info.renderOptions.classes[strikethroughClass] = true; })
      ));
    });

    async function isStruckThrough(session: Session, row: Row) {
      // for backwards compatibility
      const isStruckThroughOldStyle = await session.document.store._isStruckThroughOldFormat(row);
      if (isStruckThroughOldStyle) { return true; }

      const text = await session.document.getText(row);
      return (text.slice(0, 2) === '~~') && (text.slice(-2) === '~~');
    }

    async function addStrikeThrough(session: Session, row: Row) {
      await session.addChars(row, -1, ['~', '~']);
      await session.addChars(row, 0, ['~', '~']);
    }

    async function removeStrikeThrough(session: Session, row: Row) {
      await session.delChars(row, -2, 2);
      await session.delChars(row, 0, 2);
    }

    api.registerAction(
      'toggle-strikethrough',
      'Toggle strikethrough for a row',
      async function({ session }) {
        if (await isStruckThrough(session, session.cursor.row)) {
          await removeStrikeThrough(session, session.cursor.row);
        } else {
          await addStrikeThrough(session, session.cursor.row);
        }
      },
    );

    // TODO: this should maybe strikethrough children, since UI suggests it?
    api.registerAction(
      'visual-line-toggle-strikethrough',
      'Toggle strikethrough for rows',
      async function({ session, visual_line }) {
        if (visual_line == null) {
          throw new Error('Visual_line mode arguments missing');
        }

        const is_struckthrough = await Promise.all(
          visual_line.selected.map(async (path) => {
            return await isStruckThrough(session, path.row);
          })
        );
        if (_.every(is_struckthrough)) {
          await Promise.all(
            visual_line.selected.map(async (path) => {
              await removeStrikeThrough(session, path.row);
            })
          );
        } else {
          await Promise.all(
            visual_line.selected.map(async (path, i) => {
              if (!is_struckthrough[i]) {
                await addStrikeThrough(session, path.row);
              }
            })
          );
        }
        await session.setMode('NORMAL');
      },
    );

    api.registerDefaultMappings(
      'NORMAL',
      {
        'toggle-strikethrough': [['ctrl+enter']],
      },
    );

    api.registerDefaultMappings(
      'INSERT',
      {
        'toggle-strikethrough': [['ctrl+enter', 'meta+enter']],
      },
    );

    api.registerDefaultMappings(
      'VISUAL_LINE',
      {
        'visual-line-toggle-strikethrough': [['ctrl+enter']],
      },
    );

    // TODO for workflowy mode
    // NOTE: in workflowy, this also crosses out children
    // 'toggle-strikethrough': [['meta+enter']],
  },
  (api => api.deregisterAll()),
);
