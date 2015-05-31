class Menu
  constructor: (div, fn) ->
    @div = div
    @fn = fn

    data = new Data (new store.InMemoryDataStore)
    data.load {
      line: ''
      children: ['']
    }

    @view = new View null, data
    @selection = 0

    # list of results:
    #   contents: a line of contents
    #   highlights: lines to highlight
    #   fn: call if selected
    @results = []

  up: () ->
    if not @results.length
      return
    if @selection <= 0
      @selection = @results.length - 1
    else
      @selection = @selection - 1
    do @render

  down: () ->
    if not @results.length
      return
    if @selection + 1 >= @results.length
      @selection = 0
    else
      @selection = @selection + 1
    do @render

  update: () ->
    query = do @view.curLine
    @results = @fn query
    @selection = 0
    do @render

  render: () ->
    if not @div
      return

    do @div.empty

    searchRow = $('<div>').css(
      'padding': '10px'
      'border': '1px solid black'
      'margin-bottom': '20px'
    ).appendTo @div
    searchRow.append $('<i>').addClass('fa fa-search').css(
      'margin-right': '10px'
    )

    searchBox = $('<span>').addClass('searchBox').appendTo searchRow
    @view.renderLine @view.cursor.row, searchBox

    if @results.length == 0
      message = ''
      if do @view.curLineLength == 0
        message = 'Type something to search!'
        message += '<br/>'
        message += 'Ctrl+j and Ctrl+k to move up and down'
        message += '<br/>'
        message += 'Enter to select result'
        message += '<br/>'
        message += 'Esc to cancel'
      else
        message = 'No results!  Try typing something else'
      @div.append(
        $('<div>').html(message).css(
          'font-size': '20px'
          'opacity': '0.5'
        ).addClass('center')
      )
    else
      for result, i in @results
        defaultStyle = ''
        # if i == @selection
        #   defaultStyle = 'cursor'

        resultDiv = $('<div>').css(
          'margin-bottom': '10px'
        ).appendTo @div

        icon = 'fa-circle'
        if i == @selection
          resultDiv.css 'background-color', '#EEEEEE'
          icon = 'fa-arrow-circle-right'
        resultDiv.append $('<i>').addClass('fa ' + icon + ' bullet').css(
          'margin-right': '20px'
        )
        resultLineDiv = $('<span>').appendTo resultDiv
        renderLine result.contents, resultLineDiv, {
          highlights: result.highlights
          defaultStyle: defaultStyle
        }

  select: () ->
    if not @results.length
      return
    result = @results[@selection]
    do result.fn

if module?
  View = require('./view.coffee')
  Data = require('./data.coffee')
  store = require('./datastore.coffee')

# exports
module?.exports = Menu
