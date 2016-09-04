/* eslint-disable no-unused-vars */
import React from 'react';
/* eslint-enable no-unused-vars */

import * as Plugins from '../../assets/js/plugins';

Plugins.register({
  name: 'ID Debug Mode',
  author: 'Zachary Vance',
  description: 'Display internal IDs for each node (for debugging for developers)',
  version: 1
}, (api =>
  api.registerHook('session', 'renderInfoElements', function(pathElements, info) {
    pathElements.unshift(
      <span style={{ position: 'relative', fontWeight: 'bold'}}>
        {' ' + info.path.getAncestry().join(', ')}
      </span>
    );

    return pathElements;
  })
), (api => api.deregisterAll())
);
