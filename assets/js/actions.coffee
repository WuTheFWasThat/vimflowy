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
    view.data.deleteChars @row, @col, @chars.length
    view.setCur @row, @col
    view.drawRow @row
