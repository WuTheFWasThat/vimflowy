/* globals virtualDom */
import Plugins from '../../assets/js/plugins';

Plugins.register({
  name: 'ID Debug Mode',
  author: 'Zachary Vance',
  description: 'Display internal IDs for each node (for debugging for developers)',
  version: 1
}, (api =>
  api.registerHook('session', 'renderInfoElements', function(pathElements, info) {
    pathElements.unshift(virtualDom.h('span', {
      style: {
        position: 'relative',
        'font-weight': 'bold'
      }
    }, ' ' + info.path.getAncestry().join(', ')));

    return pathElements;
  })
), (api => api.deregisterAll())
);
