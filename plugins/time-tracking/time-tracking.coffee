(() ->

  pad = (val, length, padChar = '0') ->
    val += ''
    numPads = length - val.length
    if (numPads > 0) then new Array(numPads + 1).join(padChar) + val else val

  sum = (a) ->
    total = 0
    for x in a
      total += x
    total

  Plugins.register {
    name: "Time Tracking"
    author: "Zachary Vance"
    description: "Keeps track of how much time has been spent in each row (including its descendents)"
    version: 3
    requirements: []
  }, (api) ->
    time_tracker = new TimeTrackingPlugin api

  class TimeTrackingPlugin
    constructor: (@api) ->
      do @enableAPI

    enableAPI: () ->
      @logger = @api.logger
      @logger.info "Loading time tracking"
      @api.cursor.on 'rowChange', (@onRowChange.bind @)
      @onRowChange undefined, @api.cursor.row # Initial setup
      @api.view.on 'renderLine', (@onRenderLine.bind @)
      @api.view.data.on 'descendentRemoved', (@onDescendentRemoved.bind @)
      @api.view.data.on 'descendentAdded', (@onDescendentAdded.bind @)
      @rowChanges = []
      @currentRow = null
      @displayTime = true
      # TODO: Add view.on 'exit' to view
      #@api.view.on 'exit', (@onExit.bind @)

    getRowData: (row, keytype) ->
      key = "#{row.id}:#{keytype}"
      @api.getData key
    setRowData: (row, keytype, value) ->
      key = "#{row.id}:#{keytype}"
      @api.setData key, value
    transformRowData: (row, keytype, transform) ->
      @setRowData row, keytype, (transform (@getRowData row, keytype))

    _date: (timestamp) ->
      "#{timestamp.getFullYear()}-#{timestamp.getMonth()}-#{timestamp.getDate()}"
    dateOf: (timestamp) ->
      day = new Date(timestamp)
      day.setHours 0
      day.setMinutes 0
      day.setSeconds 0
      day.setMilliseconds 0
      day
    # Return one timestamp on each day between the two timetamps, inclusive
    daysBetween: (start, stop) ->
      cur = @dateOf start
      days = []
      while cur < stop
        days.push (new Date cur)
        cur.setDay (cur.getDay() + 1)
      days

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
    onRowPeriod: (period) ->
      period.time = (period.stop - period.start)
      @transformRowData period.row, "timePeriods", (current) =>
        current ?= []
        current.push period
        current
      @_addTimeToRow period.row, period.time, period.stop
      @_addTimeToAncestors period.row, period.time, period.stop
    onDescendentRemoved: (event) ->
      ancestor = @api.view.data.canonicalInstance event.ancestorId
      @_rebuildTreeTimes ancestor # Could avoid lookups by knowing exact changes, if needed
    onDescendentAdded: (event) ->
      ancestor = @api.view.data.canonicalInstance event.ancestorId
      @_rebuildTreeTimes ancestor # Could avoid lookups by knowing exact changes, if needed

    _combineDailyTimes: (dailyTimes...) ->
      combined = {}
      for date in  _.union (_.map _.keys, dailyTimes)
        combined[date] = 0
        for dailyTime in dailyTimes
          combined[date] += dailyTime[date] ? 0
      combined
    _addTimeToRow: (row, time, day) ->
      @transformRowData row, "rowTotalTime", (current) ->
        (current ? 0) + time
      @transformRowData row, "rowDailyTime", (current) =>
        key = @_date day
        current ?= {}
        current[key] = (current[key] ? 0) + time
        current
    _rebuildRowTimes: (row) -> # Unused, but keep for data migration in future versions
      totalTime = 0
      dailyTime = {}
      for period in @getRowData row, "timePeriods" ? []
        totalTime += period.time
        key = @_date day
        dailyTime[key] = (dailyTime[key] ? 0) + period.time
      @setRowData row, "rowTotalTime", totalTime
      @setRowData row, "rowDailyTime", dailyTime
    _addTimeToAncestors: (row, time, day) ->
      for ancestorId in @api.view.data.allAncestors row.id, { inclusive: true }
        ancestor = @api.view.data.canonicalInstance ancestorId
        @transformRowData ancestor, "treeTotalTime", (current) ->
          (current ? 0) + time
        @transformRowData ancestor, "treeDailyTime", (current) =>
          key = @_date day
          current ?= {}
          current[key] = (current[key] ? 0) + time
          current
    _rebuildTreeTimes: (row) ->
      children = @api.view.data.getChildren row

      childTotalTimes = _.map children, (child) -> @getRowData child, "treeTotalTime"
      rowTotalTime = @getRowData row, "rowTotalTime"
      totalTimes = _.compact ([rowTotalTime].concat childTotalTimes)
      totalTime = sum totalTimes
      @setRowData row, "treeTotalTime", (current) =>

      childDailyTimes = _.map children, (child) -> @getRowData child, "treeDailyTime"
      rowDailyTime = @getRowData row, "rowDailyTime"
      dailyTimes = _.compact ([rowDailyTime].concat childDailyTimes)
      dailyTime = @_combineDailyTimes.apply @, dailyTimes
      @setRowData row, "treeDailyTime", dailyTime

    rowTime: (row, range) ->
      if range?
        times = @getRowData row, "treeDailyTime"
        time = 0
        for date in @daysBetween range.start, range.stop
          time += times[@_date date] ? 0
        time
      else
        @getRowData row, "treeTotalTime"

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
        if time > 1000
          @logger.info "Rendering time for row #{row.id} as #{time}"
          renderArray.push virtualDom.h 'span', {
            className: 'time'
          }, " " + (@printTime time)

)()
