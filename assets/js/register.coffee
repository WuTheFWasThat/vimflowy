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
        @view.addCharsAtCursor @chars
      else
        @view.addCharsAfterCursor @chars, {cursor: 'beforeEnd'}
    else if @type == TYPES.ROWS
      row = @view.cursor.row
      parent = @view.data.getParent row
      index = @view.data.indexOf row

      if options.before
        @view.attachBlocks parent, @rows, index
      else
        children = @view.data.getChildren row
        if children.length > 0
          @view.attachBlocks row, @rows, 0
        else
          @view.attachBlocks parent, @rows, (index + 1)

# exports
module?.exports = Register
