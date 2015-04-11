# actions mutate the data of a view, and are undoable

class Action
  apply: (view) ->
    return
  rewind: (view) ->
    return

class AddChars extends Action
  constructor: (row, col, chars) ->
    @row = row
    @col = col
    @chars = chars
  apply: (view) ->
    view.data.writeChars @row, @col, @chars
    view.setCur @row, (@col + @chars.length)
    view.drawRow @row
  rewind: (view) ->
    reverse = new DelChars @row, @col, @chars.length
    reverse.apply view

class DelChars extends Action
  constructor: (row, col, nchars) ->
    @row = row
    @col = col
    @nchars = nchars
  apply: (view) ->
    @chars = view.data.deleteChars @row, @col, @nchars
    console.log @chars, @chars.length, @nchars
    view.setCur @row, @col
    view.drawRow @row
  rewind: (view) ->
    reverse = new AddChars @row, @col, @chars
    reverse.apply view
