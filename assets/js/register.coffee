class Register
  TYPES = {
    NONE: 0
    CHARS: 1
    ROWS: 2
  }

  constructor: (view) ->
    @view = view
    @type = TYPES.NONE
    return @

  saveChars: (chars) ->
    @type = TYPES.CHARS
    @chars = chars

  saveRows: (rows) ->
    # rows: array of row IDs

    @type = TYPES.ROWS
    @rows = rows

  paste: (options) ->
    if @type == TYPES.CHARS
      if options.before
        return @view.addCharsAtCursor @chars
      else
        return @view.addCharsAfterCursor @chars
    else if @type == TYPES.ROWS
      row = @view.cursor.row
      if options.before
        row = @view.data.prevVisible row, {allowRoot: true}
      return @view.addRows row, @rows

# exports
module?.exports = Register
