((exports) ->

  # actions mutate the data of a view, and are undoable

  class Action
    apply: (view) ->
      return
    rewind: (view) ->
      return

  class AddChars extends Action
    constructor: (row, col, chars, options = {}) ->
      @row = row
      @col = col
      @chars = chars
      @options = options
    apply: (view) ->
      view.data.writeChars @row, @col, @chars
      view.setCur @row, (@col + @chars.length), @options
      view.drawRow @row
    rewind: (view) ->
      reverse = new DelChars @row, @col, @chars.length
      reverse.apply view

  class DelChars extends Action
    constructor: (row, col, nchars, options = {}) ->
      @row = row
      @col = col
      @nchars = nchars
      @options = options
    apply: (view) ->
      @chars = view.data.deleteChars @row, @col, @nchars
      view.setCur @row, @col, @options
      view.drawRow @row
    rewind: (view) ->
      view.data.writeChars @row, @col, @chars
      view.drawRow @row

  # NOTE: this generalized add/del chars...
  class SpliceChars extends Action
    constructor: (row, col, nchars, chars, options = {}) ->
      @row = row
      @col = col
      @nchars = nchars
      @chars = chars

      options.cursor ?= 'end'
      @options = options

    apply: (view) ->
      @deletedChars = view.data.deleteChars @row, @col, @nchars
      view.data.writeChars @row, @col, @chars

      if @options.cursor == 'end'
        view.setCur @row, (@col + @chars.length)
      else if @options.cursor == 'pastEnd'
        view.setCur @row, (@col + @chars.length), {pastEnd: true}

      view.drawRow @row
    rewind: (view) ->
      view.data.deleteChars @row, @col, @chars.length
      view.data.writeChars @row, @col, @deletedChars
      view.drawRow @row

  exports.AddChars = AddChars
  exports.DelChars = DelChars
  exports.SpliceChars = SpliceChars
)(if typeof exports isnt 'undefined' then exports else window.actions = {})
