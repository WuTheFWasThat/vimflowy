import React from 'react'; // tslint:disable-line no-unused-variable

import * as Plugins from '../../assets/js/plugins';

Plugins.register({
  name: 'ID Debug Mode',
  author: 'Zachary Vance',
  description: 'Display internal IDs for each node (for debugging for developers)',
  version: 1,
}, (api =>
  api.registerHook('session', 'renderAfterLine', function(pathElements, { path }) {
    pathElements.push(
      <span key='debug' style={{ position: 'relative', fontWeight: 'bold'}}>
        {' ' + path.getAncestry().join(', ')}
      </span>
    );

    return pathElements;
  })
), (api => api.deregisterAll())
);
