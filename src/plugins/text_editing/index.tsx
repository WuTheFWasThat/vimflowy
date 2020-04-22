import * as React from 'react'; // tslint:disable-line no-unused-variable

import { registerPlugin } from '../../assets/ts/plugins';
import Path from '../../assets/ts/path';
import Session from '../../assets/ts/session';

registerPlugin(
  {
    name: 'Text Editing',
    author: 'shady2k',
    description: (
      <div>
      Lets you to join visual block lines
      </div>
    ),
    version: 1,
  },
  function(api) {
    api.registerAction(
      'visual-line-join',
      'Join all selected rows',
      async function({ session, visual_line }) {
        if (visual_line == null) {
          throw new Error('Visual_line mode arguments missing');
        }

        let result: string = '';
        if (visual_line.num_rows >= 1) {
          const resultArr = await Promise.all(
            visual_line.selected.map(async (path) => {
              return await getTextRecusive(session, path);
            })
          );

          const resultArrClear = resultArr.map(function(x) { return x.replace(/(?:\r\n|\r|\n)/g, ''); });
          result = resultArrClear.join('\n');

          if (result) {
            // const line = result.split('');
            // const row_length = await session.document.getLength(visual_line.start_i);
            await session.delBlocks(visual_line.parent.row, visual_line.start_i, visual_line.num_rows, {addNew: false});
            await session.addBlocks(visual_line.parent, visual_line.start_i, [result]);
            /*await session.delChars(visual_line.start.row, 0, row_length);
            await session.addChars(visual_line.start.row, 0, line);*/
          }
        }

        await session.setMode('NORMAL');
      },
    );

    api.registerDefaultMappings(
        'VISUAL_LINE',
        {
            'visual-line-join': [['J']]
        }
    );

  },
  (api => api.deregisterAll()),
);

async function getTextRecusive(session: Session, path: Path) {
  let result: string[] = [];

  const text = await session.document.getText(path.row);
  result.push(text);

  if (await session.document.hasChildren(path.row)) {
    let children = await session.document.getChildren(path);

    const resultChildren = await Promise.all(
      children.map(async (childrenPath) => {
        return await getTextRecusive(session, childrenPath);
      })
    );

    for (let item in resultChildren) {
      result.push(resultChildren[item]);
    }
  }

  return result.join('\n');
}
