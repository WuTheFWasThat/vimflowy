(() ->
  class TimeTrackingPlugin
    @metadata =
      name: "Time Tracking"
      author: "Zachary Vance"
      description: "Keeps track of how much time has been spent in a "
      version: 1
      stores_data: true
      data_version: 1
      requirements: []

    constructor: (@api) ->
      do @enableAPI
    
    enableAPI: () ->
      @logger = do @api.getLogger
      @logger.info "Loading time tracking"
      @database = do @api.getDatabase
      @api.cursor.on 'rowChange', (@onRowChange.bind @)
      # TODO: Add view.on 'exit' to view
      #@api.view.on 'exit', (@onExit.bind @)

    #onExit: () ->
    #  @onRowFrom @api.cursor.row

    onRowChange: (from, to) ->
      @logger.debug "Switching from row #{from.id} to row #{to.id}"
      @onRowFrom from
      @onRowTo to

    onRowFrom: (from) ->
      time = new Date()
      @database.transformRowData from, (current) =>
        current ?= []
        current.push
          stop: time
          row: do from.getAncestry
        @logger.debug current
        current
     
     onRowTo: (to) ->
      time = new Date()
      @database.transformRowData to, (current) =>
        current ?= []
        current.push
          start: time
          row: do to.getAncestry
        @logger.debug current
        current

    # exports
    module?.exports = TimeTrackingPlugin
    window?.registerPlugin?(TimeTrackingPlugin)
)()
