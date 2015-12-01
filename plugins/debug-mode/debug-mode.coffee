(() ->

  Plugins.register {
    name: "ID Debug Mode"
    author: "Zachary Vance"
    description: "Display internal IDs for each node"
    version: 1
  }, (api) ->
    api.view.addRenderHook 'rowElements', (rowElements, info) ->
      rowElements.unshift virtualDom.h 'span', {
        style: {
          position: 'relative'
          'font-weight': 'bold'
        }
      }, " " + (do info.row.debug)
      return rowElements
)()
