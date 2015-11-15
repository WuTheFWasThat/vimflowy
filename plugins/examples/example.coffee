(() ->
  Plugins.register {
    name: "Hello World Coffee"
    author: "Zachary Vance"
    description: "Prints 'Hello World' when the plugin is loaded"
    version: 1
    requirements: []
  }, (api) ->
    console.log "Hello world plugin written in coffeescript!"
)()
