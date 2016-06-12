Plugins = require '../../assets/js/plugins.coffee'

Plugins.register {
  name: "ID Debug Mode"
  author: "Zachary Vance"
  description: "Display internal IDs for each node (for debugging for developers)"
  version: 1
}, ((api) ->
  api.registerHook 'session', 'renderInfoElements', (pathElements, info) ->
    pathElements.unshift virtualDom.h 'span', {
      style: {
        position: 'relative'
        'font-weight': 'bold'
      }
    }, " " + (do info.path.getAncestry).join ", "

    return pathElements
), ((api) ->
  do api.deregisterAll
)
