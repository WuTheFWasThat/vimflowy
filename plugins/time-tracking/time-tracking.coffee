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
  }, (api) ->
    time_tracker = new TimeTrackingPlugin api

  class TimeTrackingPlugin
    constructor: (@api) ->
      do @enableAPI

    enableAPI: () ->
      @logger = @api.logger
      @logger.info "Loading time tracking"
      @api.cursor.on 'rowChange', (@onRowChange.bind @)
      @onRowChange null, @api.cursor.row # Initial setup
      @api.view.on 'renderLine', (@onRenderLine.bind @)
      @api.view.data.on 'afterDescendentRemoved', (@onDescendentRemoved.bind @)
      @api.view.data.on 'afterDescendentAdded', (@onDescendentAdded.bind @)
      @rowChanges = []
      @currentRow = null
      @api.view.on 'exit', () =>
        @onRowChange @currentRow, null
      CMD_TOGGLE = @api.registerCommand {
        name: 'TOGGLE'
        default_hotkeys:
          normal_like: ['Z']
      }
      CMD_TOGGLE_DISPLAY = @api.registerCommand {
        name: 'TOGGLE_DISPLAY'
        default_hotkeys:
          normal_like: ['d']
      }
      CMD_TOGGLE_LOGGING = @api.registerCommand {
        name: 'TOGGLE_LOGGING'
        default_hotkeys:
          normal_like: ['l']
      }
      @api.registerAction [@api.modes.modes.NORMAL], CMD_TOGGLE, {
        description: 'Toggle a setting',
      }, {}
      @api.registerAction [@api.modes.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_DISPLAY], {
        description: 'Toggle whether time spent on each row is displayed',
      }, () =>
        do @toggleDisplay
      @api.registerAction [@api.modes.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_LOGGING], {
        description: 'Toggle whether time is being logged',
      }, () =>
        do @toggleLogging
      

    getRowData: (id, keytype) ->
      key = "#{id}:#{keytype}"
      @api.getData key
    setRowData: (id, keytype, value) ->
      key = "#{id}:#{keytype}"
      @api.setData key, value
    transformRowData: (id, keytype, transform) ->
      @setRowData id, keytype, (transform (@getRowData id, keytype))

    DEFAULT_LOGGING = true
    DEFAULT_DISPLAY = true
    isLogging: () ->
      (@api.getData "isLogging") ? DEFAULT_LOGGING
    shouldDisplayTime: () ->
      (@api.getData "display") ? DEFAULT_DISPLAY
    toggleLogging: () ->
      @logger.info "Turning logging #{if (do @isLogging) then "off" else "on"}"
      if do @isLogging
        @onRowChange @api.cursor.row, null # Final close
      else
        @onRowChange null, @api.cursor.row # Initial setup
      @api.setData "isLogging", not (do @isLogging)
      do @api.view.render
    toggleDisplay: () ->
      @logger.info "Turning display #{if (do @shouldDisplayTime) then "off" else "on"}"
      @api.setData "display", not (do @shouldDisplayTime)
      do @api.view.render

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

    onRowChange: (from, to) ->
      @logger.debug "Switching from row #{from?.id} to row #{to?.id}"
      if not do @isLogging
        return
      time = new Date()
      if @currentRow and @currentRow.id != to?.id
        @onRowPeriod { start: @currentRow.time, stop: time, id: @currentRow.id, row: from }
        delete @currentRow
      if to?
        @currentRow ?= { id: to.id, time: time }

    onRowPeriod: (period) ->
      period.time ?= period.stop - period.start
      @transformRowData period.row, "timePeriods", (current) =>
        current ?= []
        current.push period
        current
      @_addTimeToRow period.row, period.time, period.stop
      @_addTimeToAncestors period.row, period.time, period.stop
    onDescendentRemoved: (event) ->
      @logger.debug "Descendent #{event.descendentId} removed from #{event.ancestorId}"
      # Could avoid lookups by knowing exact changes, if needed
      @_rebuildTreeTimes event.ancestorId
    onDescendentAdded: (event) ->
      @logger.debug "Descendent #{event.descendentId} added to #{event.ancestorId}"
      # Could avoid lookups by knowing exact changes, if needed
      @_rebuildTreeTimes event.ancestorId

    _combineDailyTimes: (dailyTimes...) ->
      combined = {}
      for date in  _.union (_.map dailyTimes, _.keys)
        combined[date] = 0
        for dailyTime in dailyTimes
          combined[date] += dailyTime[date] ? 0
      combined
    _addTimeToRow: (row, time, day) ->
      @transformRowData row.id, "rowTotalTime", (current) ->
        (current ? 0) + time
      @transformRowData row.id, "rowDailyTime", (current) =>
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
      @setRowData row.id, "rowTotalTime", totalTime
      @setRowData row.id, "rowDailyTime", dailyTime
    _addTimeToAncestors: (row, time, day) ->
      for ancestorId in @api.view.data.allAncestors row.id, { inclusive: true }
        @transformRowData ancestorId, "treeTotalTime", (current) ->
          (current ? 0) + time
        @transformRowData ancestorId, "treeDailyTime", (current) =>
          key = @_date day
          current ?= {}
          current[key] = (current[key] ? 0) + time
          current
    _rebuildTreeTimes: (id) ->
      children = @api.view.data._getChildren id

      childTotalTimes = _.map children, (child_id) => @getRowData child_id, "treeTotalTime"
      rowTotalTime = @getRowData id, "rowTotalTime"
      totalTimes = _.compact ([rowTotalTime].concat childTotalTimes)
      totalTime = sum totalTimes
      @setRowData id, "treeTotalTime", totalTime

      childDailyTimes = _.map children, (child_id) => @getRowData child_id, "treeDailyTime"
      rowDailyTime = @getRowData id, "rowDailyTime"
      dailyTimes = _.compact ([rowDailyTime].concat childDailyTimes)
      dailyTime = @_combineDailyTimes.apply @, dailyTimes
      @setRowData id, "treeDailyTime", dailyTime

    rowTime: (row, range) ->
      if range?
        times = @getRowData row.id, "treeDailyTime"
        time = 0
        for date in @daysBetween range.start, range.stop
          time += times[@_date date] ? 0
        time
      else
        @getRowData row.id, "treeTotalTime"

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
      if do @shouldDisplayTime
        time = @rowTime row
        if time > 1000
          @logger.info "Rendering time for row #{row.id} as #{time}"
          renderArray.push virtualDom.h 'span', {
            className: 'time'
          }, " " + (@printTime time)

)()
