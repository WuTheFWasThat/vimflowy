Session = require './session.coffee'
Document = (require './document.coffee').Document
DataStore = require './datastore.coffee'
Modes = require './modes.coffee'

###
Represents the menu shown in menu mode.
Functions for paging through and selecting results, and for rendering.
Internally uses an entire session object (this is sorta weird..)
###

class Menu
  constructor: (div, fn) ->
    @div = div
    @fn = fn

    document = new Document (new DataStore.InMemory)

    # a bit of a overkill-y hack, use an entire session object internally
    @session = new Session document
    @session.setMode Modes.modes.INSERT
    @selection = 0

    # list of results:
    #   contents: a line of contents
    #   renderOptions: options for renderLine
    #   fn: call if selected
    @results = []

  up: () ->
    if not @results.length
      return
    if @selection <= 0
      @selection = @results.length - 1
    else
      @selection = @selection - 1

  down: () ->
    if not @results.length
      return
    if @selection + 1 >= @results.length
      @selection = 0
    else
      @selection = @selection + 1

  update: () ->
    query = do @session.curText
    if (JSON.stringify query) != (JSON.stringify @lastquery)
      @lastquery = query
      @results = @fn query
      @selection = 0

  select: () ->
    if not @results.length
      return
    result = @results[@selection]
    do result.fn

# exports
module.exports = Menu
