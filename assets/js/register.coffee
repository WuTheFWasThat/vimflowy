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

  saveRows: (serialized_rows) ->
    @type = TYPES.ROWS
    @serialized_rows = serialized_rows

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
        @view.addBlocks @serialized_rows, parent, index, {cursor: 'first'}
      else
        children = @view.data.getChildren row
        if children.length > 0
          @view.addBlocks @serialized_rows, row, 0, {cursor: 'first'}
        else
          @view.addBlocks @serialized_rows ,parent, (index + 1), {cursor: 'first'}

# exports
module?.exports = Register
