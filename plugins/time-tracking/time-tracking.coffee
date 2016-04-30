# Time-tracking keeps track of the amount of time spent in each subtree.
# Clones are double-counted. This is a known bug and will not be fixed.
#
Plugins = require '../../assets/js/plugins.coffee'
Modes = require '../../assets/js/modes.coffee'

Plugins.register {
  name: "Time Tracking"
  author: "Zachary Vance"
  description: "Keeps track of how much time has been spent in each row (including its descendants)"
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
    @currentRow = null
    @onRowChange null, @api.cursor.row # Initial setup
    @api.session.addHook 'renderInfoElements', (@renderTime.bind @)
    @api.session.document.on 'afterMove', (info) =>
      @_rebuildTreeTime info.id
      @_rebuildTreeTime info.old_parent, true
    @api.session.document.on 'afterAttach', (info) =>
      @_rebuildTreeTime info.id
      if info.old_detached_parent
        @_rebuildTreeTime info.old_detached_parent, true
    @api.session.document.on 'afterDetach', (info) =>
      @_rebuildTreeTime info.id

    @rowChanges = []
    @api.session.on 'exit', () =>
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
    CMD_CLEAR_TIME = @api.registerCommand {
      name: 'CLEAR_TIME'
      default_hotkeys:
        normal_like: ['c']
    }
    CMD_ADD_TIME = @api.registerCommand {
      name: 'ADD_TIME'
      default_hotkeys:
        normal_like: ['>', 'a']
    }
    CMD_SUBTRACT_TIME = @api.registerCommand {
      name: 'SUBTRACT_TIME'
      default_hotkeys:
        normal_like: ['<', 's']
    }
    @api.registerAction [Modes.modes.NORMAL], CMD_TOGGLE, {
      description: 'Toggle a setting',
    }, {}
    @api.registerAction [Modes.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_DISPLAY], {
      description: 'Toggle whether time spent on each row is displayed',
    }, () =>
      do @toggleDisplay
    @api.registerAction [Modes.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_LOGGING], {
      description: 'Toggle whether time is being logged',
    }, () =>
      do @toggleLogging
    @api.registerAction [Modes.modes.NORMAL], [CMD_TOGGLE, CMD_CLEAR_TIME], {
      description: 'Clear current row time',
    }, () =>
      do @resetCurrentRow
    me = @
    @api.registerAction [Modes.modes.NORMAL], [CMD_TOGGLE, CMD_ADD_TIME], {
      description: 'Add time to current row (in minutes)',
    }, () ->
      me.changeTimeCurrentRow @repeat
    @api.registerAction [Modes.modes.NORMAL], [CMD_TOGGLE, CMD_SUBTRACT_TIME], {
      description: 'Subtract time from current row (in minutes)',
    }, () ->
      me.changeTimeCurrentRow -@repeat

    setInterval (() =>
      if @currentRow?
        curTime = new Date() - @currentRow.time
        $('.curtime').text (@printTime curTime)
    ), 1000

  changeTimeCurrentRow: (delta_minutes) ->
    if @currentRow?
      curTime = new Date() - @currentRow.time
      curTime += delta_minutes * 60 * 1000
      if curTime < 0
        @currentRow.time = new Date()
        @modifyTimeForId @currentRow.id, curTime
      else
        @currentRow.time = new Date() - curTime

  getRowData: (id, keytype, default_value=null) ->
    key = "#{id}:#{keytype}"
    @api.getData key, default_value

  setRowData: (id, keytype, value) ->
    key = "#{id}:#{keytype}"
    @api.setData key, value

  transformRowData: (id, keytype, transform) ->
    @setRowData id, keytype, (transform (@getRowData id, keytype))

  isLogging: () ->
    @api.getData "isLogging", true

  toggleLogging: () ->
    isLogging = do @isLogging
    @logger.info "Turning logging #{if isLogging then "off" else "on"}"
    if isLogging
      @onRowChange @api.cursor.row, null # Final close
    else
      @onRowChange null, @api.cursor.row # Initial setup
    @api.setData "isLogging", (not isLogging)
    do @api.session.render

  shouldDisplayTime: () ->
    @api.getData "display", true

  toggleDisplay: () ->
    shouldDisplay = do @shouldDisplayTime
    @logger.info "Turning display #{if shouldDisplay then "off" else "on"}"
    @api.setData "display", (not shouldDisplay)
    do @api.session.render

  onRowChange: (from, to) ->
    @logger.debug "Switching from row #{from?.id} to row #{to?.id}"
    if not do @isLogging
      return
    time = new Date()
    if @currentRow and @currentRow.id != to?.id
      @modifyTimeForId from.id, (time - @currentRow.time)
      @currentRow = null
    if to?
      @currentRow ?= { id: to.id, time: time }

  resetCurrentRow: () ->
    if @currentRow
      @currentRow.time = new Date()

  modifyTimeForId: (id, delta) ->
    @transformRowData id, "rowTotalTime", (current) ->
      (current ? 0) + delta
    @_rebuildTreeTime id, true

  _rebuildTotalTime: (id) ->
    children = @api.session.document._getChildren id
    detached_children = @api.session.document.store.getDetachedChildren id

    childTotalTimes = _.map children.concat(detached_children), (child_id) => @getRowData child_id, "treeTotalTime", 0
    rowTime = @getRowData id, "rowTotalTime", 0
    totalTime = childTotalTimes.reduce ((a,b) -> (a+b)), rowTime
    @setRowData id, "treeTotalTime", totalTime

  _rebuildTreeTime: (id, inclusive = false) ->
    for ancestor_id in @api.session.document.allAncestors id, { inclusive: inclusive }
      @_rebuildTotalTime ancestor_id

  rowTime: (row) ->
    @getRowData row.id, "treeTotalTime", 0

  pad = (val, length, padChar = '0') ->
    val += ''
    numPads = length - val.length
    if (numPads > 0) then new Array(numPads + 1).join(padChar) + val else val

  printTime: (ms) ->
    sign = ""
    if ms < 0
      sign = "-"
      ms = - ms
    seconds = Math.floor (ms /     1000 % 60)
    minutes = Math.floor (ms /    60000 % 60)
    hours   = Math.floor (ms /  3600000)
    if hours > 0
      "#{sign}#{hours}h:#{pad(minutes, 2)}m"
    else if minutes > 0
      "#{sign}#{minutes}m:#{pad(seconds, 2)}s"
    else
      "#{sign}#{seconds}s"

  renderTime: (elements, renderData) ->
    if do @shouldDisplayTime
      time = @rowTime renderData.row

      isCurRow = renderData.row.id == @currentRow?.id

      if isCurRow or time > 1000
        timeStr = " "
        timeStr += (@printTime time)
        if isCurRow
          timeStr += " + "
        elements.push virtualDom.h 'span', {
          className: 'time'
        }, timeStr

        if isCurRow
          curTime = new Date() - @currentRow.time
          elements.push virtualDom.h 'span', {
            className: 'time curtime'
          }, (@printTime curTime)
    elements
