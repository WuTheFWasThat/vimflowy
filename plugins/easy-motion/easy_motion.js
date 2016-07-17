/* globals virtualDom */

import _ from 'lodash';
import * as Plugins from '../../assets/js/plugins';

Plugins.register({
  name: 'Easy motion',
  author: 'Jeff Wu',
  description: 'Lets you easily jump between rows.  Based on https://github.com/easymotion/vim-easymotion'
}, (function(api) {
  let EASY_MOTION_MAPPINGS = null;

  let CMD_EASY_MOTION = api.registerCommand({
    name: 'EASY_MOTION',
    default_hotkeys: {
      normal_like: ['space']
    }
  });

  api.registerMotion(CMD_EASY_MOTION, {
    description: 'Jump to a visible row (based on EasyMotion)',
    multirow: true,
  }, function() {
    let key = this.keyStream.dequeue();
    if (key === null) {
      this.keyStream.wait();

      let paths = (this.session.getVisiblePaths()).filter(
        path => !path.is(this.session.cursor.path)
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

      let mappings = {
        key_to_path: {},
        path_to_key: {}
      };
      _.zip(paths, keys).forEach((pair) => {
        let [path, key] = pair;
        mappings.key_to_path[key] = path;
        mappings.path_to_key[JSON.stringify(path.getAncestry())] = key;
      });
      EASY_MOTION_MAPPINGS = mappings;

      return null;
    } else {
      return function(cursor /*, options */) {
        if (key in EASY_MOTION_MAPPINGS.key_to_path) {
          let path = EASY_MOTION_MAPPINGS.key_to_path[key];
          cursor.set(path, 0);
        }
        return EASY_MOTION_MAPPINGS = null;
      };
    }
  });

  return api.registerHook('session', 'renderBullet', function(bullet, info) {
    let ancestry_str = JSON.stringify(info.path.getAncestry());
    if (EASY_MOTION_MAPPINGS && ancestry_str in EASY_MOTION_MAPPINGS.path_to_key) {
      let char = EASY_MOTION_MAPPINGS.path_to_key[ancestry_str];
      bullet = virtualDom.h('span', {className: 'bullet theme-text-accent easy-motion'}, [char]);
    }
    return bullet;
  });
}), (api => api.deregisterAll())
);
