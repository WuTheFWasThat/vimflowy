(() ->
  pad = (val, length, padChar = '0') ->
    val += ''
    numPads = length - val.length
    if (numPads > 0) then new Array(numPads + 1).join(padChar) + val else val
  class TimeTrackingPlugin
    @metadata =
      name: "Time Tracking"
      author: "Zachary Vance"
      description: "Keeps track of how much time has been spent in each row (including its descendents)"
      version: 1 # TODO: DO NOT RELEASE until optimized (TODOs in this file done)
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
      @api.view.on 'renderLine', (@onRenderLine.bind @)
      @displayTime = true
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
      @database.transformRowData from, "raw", (current) =>
        current ?= []
        current.push
          stop: time
          row: do from.getAncestry
        @logger.debug current
        current
      # TODO: Update summary statistics for all ancestors including this one
      # TODO: Debounce raw data; this is too much
     
     onRowTo: (to) ->
      time = new Date()
      @database.transformRowData to, "raw", (current) =>
        current ?= []
        current.push
          start: time
          row: do to.getAncestry
        @logger.debug current
        current
    
     rowTime: (row, range) ->
      if range?
        # To implement range queries effectively on a hierarchical datastructure, we'd need 2-D range trees which support an efficient move/delete operator.
        # This is possible, but would take around 2 days to implement
        @api.showMessage "Range queries are very slow, please wait"
        start = null
        time = 0
        for datum in (@database.getRowData row, "raw") || []
          start ?= datum.start
          if datum.stop?
            start = null
            time += datum.stop - sstart
        return time
      else
        # Uses linear scan right now as a proof of concept; do not release yet
        # TODO: Include children
        start = null
        time = 0
        for datum in (@database.getRowData row, "raw") || []
          if datum.start?
            start ?= Date.parse datum.start
          if start? and datum.stop?
            stop = Date.parse datum.stop
            time += stop - start
            start = null
        for child in @api.view.data.getChildren row
          time += @rowTime child
        return time
    printTime: (ms) ->
      seconds = Math.floor (ms /     1000 % 60)
      minutes = Math.floor (ms /    60000 % 60)
      hours   = Math.floor (ms /  3600000 % 60)
      days    = Math.floor (ms / 86400000)
      if days > 0
        "#{days}d"
      else if hours > 0
        "#{hours}:#{pad(minutes, 2)}h"
      else if minutes > 0
        "#{minutes}:#{pad(seconds, 2)}m"
      else if seconds > 0
        "#{seconds}s"

    onRenderLine: (row, renderArray, options) ->
      if @displayTime
        time = @rowTime row
        if time > 0
          @logger.info "Rendering time for row #{row.id} as #{time}"
          renderArray.push virtualDom.h 'span', {
            className: 'time'
          }, " " + (@printTime time)

    # exports
    module?.exports = TimeTrackingPlugin
    window?.registerPlugin?(TimeTrackingPlugin)
)()
