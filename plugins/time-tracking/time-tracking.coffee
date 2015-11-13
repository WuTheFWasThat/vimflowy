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
      data_version: 2
      requirements: []

    constructor: (@api) ->
      do @enableAPI
    
    enableAPI: () ->
      @logger = do @api.getLogger
      @logger.info "Loading time tracking"
      @database = do @api.getDatabase
      @api.cursor.on 'rowChange', (@onRowChange.bind @)
      @onRowChange undefined, @api.cursor.row # Initial setup
      @api.view.on 'renderLine', (@onRenderLine.bind @)
      @rowChanges = []
      @currentRow = null
      @displayTime = true
      # TODO: Add view.on 'exit' to view
      #@api.view.on 'exit', (@onExit.bind @)

    _date: (timestamp) ->
      "#{timestamp.getFullYear()}-#{timestamp.getMonth()}-#{timestamp.getDate()}"
    _timeForDayKey: (timestamp) ->
      "totalTimeForDay-#{@_date timestamp}"
    dateRange: (start, stop) ->
      [stop] #TODO: Not done at all

    #onExit: () ->
    #  @onRowFrom @api.cursor.row

    onRowChange: (from, to) ->
      @logger.debug "Switching from row #{from?.id} to row #{to?.id}"
      time = new Date()
      if @currentRow? and @currentRow.id != to.id
        @onRowPeriod { start: @currentRow.time, stop: time, id: @currentRow.id, row: from }
        delete @currentRow
      @currentRow ?= { id: to.id, time: time }

    # TODO: Debounce this function for batch processing
    # TODO: Update summary statistics for all ancestors including this one -- make sure ancestors update on delete/add/move
    onRowPeriod: (period) ->
      @database.transformRowData period.row, "timePeriods", (current) =>
        current ?= []
        current.push period
        current
      @database.transformRowData period.row, "totalTime", (current) =>
        (current ? 0) + (period.stop - period.start)
      @database.transformRowData period.row, (@_timeForDayKey period.stop), (current) =>
        (current ? 0) + (period.stop - period.start)
    
    rowTime: (row, range) ->
      if range?
        @api.showMessage "Range queries are very slow, please wait"
        time = 0
        for date in @dateRange range.start, range.stop
          time += @database.getRowData row, (@_timeForDayKey date)
          for child in @api.view.data.getChildren row
            time += @rowTime child
        time
      else
        time = @database.getRowData row, "totalTime"
        for child in @api.view.data.getChildren row
          time += @rowTime child
        time
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
