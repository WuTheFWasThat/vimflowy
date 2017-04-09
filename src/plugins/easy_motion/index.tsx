import _ from 'lodash';
import React from 'react'; // tslint:disable-line no-unused-variable

import Path from '../../assets/js/path';
import { registerPlugin } from '../../assets/js/plugins';

type EasyMotionMappings = {
  key_to_path: {[key: string]: Path},
  path_to_key: {[serialized_path: string]: string},
};

registerPlugin<void>(
  {
    name: 'Easy motion',
    author: 'Jeff Wu',
    description: (
      <div>
      Lets you easily jump between rows, by default with space key.
      Based on <a href='https://github.com/easymotion/vim-easymotion'>this vim plugin</a>
      </div>
    ),
  },
  function(api) {
    let EASY_MOTION_MAPPINGS: EasyMotionMappings | null = null;

    api.registerMotion(
      'easy-motion',
      'Jump to a visible row (based on EasyMotion)',
      async function({ session, keyStream, keyHandler }) {
        let paths: Array<Path> = (await session.getVisiblePaths()).filter(
          path => !path.is(session.cursor.path)
        );

        let keys = [
          'Z', 'X', 'C', 'V',
          'Q', 'W', 'E', 'R', 'T',
          'A', 'S', 'D', 'F',
          'z', 'x', 'c', 'v',
          'q', 'w', 'e', 'r', 't',
          'a', 's', 'd', 'f',
          'g', 'h', 'j', 'k', 'l',
          'y', 'u', 'i', 'o', 'p',
          'b', 'n', 'm',
          'G', 'H', 'J', 'K', 'L',
          'Y', 'U', 'I', 'O', 'P',
          'B', 'N', 'M',
        ];

        let start;
        if (keys.length > paths.length) {
          start = (keys.length - paths.length) / 2;
          keys = keys.slice(start, start + paths.length);
        } else {
          start = (paths.length - keys.length) / 2;
          paths = paths.slice(start, start + paths.length);
        }

        let mappings: EasyMotionMappings = {
          key_to_path: {},
          path_to_key: {},
        };
        // NOTE: _.zip has a stupid type definition
        _.zip<Path | string>(paths, keys).forEach((pair: [any, any]) => {
          const [path, jump_key]: [Path, string] = pair;
          mappings.key_to_path[jump_key] = path;
          mappings.path_to_key[JSON.stringify(path.getAncestry())] = jump_key;
        });

        EASY_MOTION_MAPPINGS = mappings;

        await Promise.all(_.values(EASY_MOTION_MAPPINGS.key_to_path).map(
          async (path) => await api.updatedDataForRender(path.row)
        ));
        // TODO hacky way to trigger re-render
        keyHandler.emit('handledKey');

        const key = await keyStream.dequeue();

        return async function(cursor /*, options */) {
          if (EASY_MOTION_MAPPINGS === null) {
            throw new Error('Easy motion mappings were not set, as expected');
          }
          if (key in EASY_MOTION_MAPPINGS.key_to_path) {
            let path = EASY_MOTION_MAPPINGS.key_to_path[key];
            await cursor.setPosition(path, 0);
          }
          await Promise.all(_.values(EASY_MOTION_MAPPINGS.key_to_path).map(
            async (path) => await api.updatedDataForRender(path.row)
          ));
          EASY_MOTION_MAPPINGS = null;
        };
      },
    );

    api.registerDefaultMappings(
      'NORMAL',
      {
        'easy-motion': [['space']],
      },
    );

    api.registerHook('session', 'renderBullet', function(bullet, info) {
      let ancestry_str = JSON.stringify(info.path.getAncestry());
      if (EASY_MOTION_MAPPINGS !== null) {
        if (ancestry_str in EASY_MOTION_MAPPINGS.path_to_key) {
          bullet = (
            <span key='easymotion' style={{fontWeight: 'bold'}}
                  className='bullet theme-text-accent'>
              {EASY_MOTION_MAPPINGS.path_to_key[ancestry_str]}
            </span>
          );
        }
      }
      return bullet;
    });
  },
  (api => api.deregisterAll()),
);
