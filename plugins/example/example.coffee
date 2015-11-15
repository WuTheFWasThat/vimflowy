(() ->
  class HelloWorldPlugin
    @metadata =
      name: "Hello World"
      author: "Zachary Vance"
      description: "Prints 'Hello World' when the plugin is loaded"
      version: 1
      stores_data: false
      #data_version: 0
      requirements: []

    constructor: (@api) ->
      do @enable
    
    enable: () ->
      console.log "Hello world"

    # exports
    module?.exports = HelloWorldPlugin
    window?.registerPlugin?(HelloWorldPlugin)
)()
