(() ->

  Plugins.register {
    name: "ID Debug Mode"
    author: "Zachary Vance"
    description: "Display internal IDs for each node"
    version: 1
  }, (api) ->
    new DebuggingPlugin api

  class DebuggingPlugin
    constructor: (@api) ->
      do @enableAPI

    enableAPI: () ->
      @api.view.on 'renderLine', (@onRenderLine.bind @)

    onRenderLine: (row, renderArray, options) ->
      renderArray.push virtualDom.h 'span', {
        className: 'debug'
      }, " " + (do row.debug)
)()
