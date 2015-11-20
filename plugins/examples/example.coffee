(() ->
  Plugins.register {
    name: "Hello World coffee"
    version: 1
    author: "Zachary Vance"
    description: "Prints 'Hello World' when the plugin is loaded"
    dependencies: []
  }, ((api) ->
    console.log "Hello world plugin written in coffeescript!"
  ), (() ->
    console.log "Goodbye, world! - coffee"
  )
)()
