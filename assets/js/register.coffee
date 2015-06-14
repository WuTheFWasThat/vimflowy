class Register
  @TYPES = {
    NONE: 0
    CHARS: 1
    ROWS: 2
  }

  constructor: (view) ->
    @view = view
    @type = Register.TYPES.NONE
    return @

  saveChars: (chars) ->
    @type = Register.TYPES.CHARS
    @chars = chars

  saveRows: (serialized_rows) ->
    @type = Register.TYPES.ROWS
    @serialized_rows = serialized_rows

  serialize: () ->
    data = ''
    if @type == Register.TYPES.CHARS
      data = @chars
    else if @type == Register.TYPES.ROWS
      data = @serialized_rows
    return {type: @type, data: data}

  deserialize: (serialized) ->
    delete @chars
    delete @serialized_rows
    @type = serialized.type
    if @type == Register.TYPES.CHARS
      @chars = serialized.data
    else if @type == Register.TYPES.ROWS
      @serialized_rows = serialized.data

  paste: (options) ->
    if @type == Register.TYPES.CHARS
      if options.before
        @view.addCharsAtCursor @chars
      else
        @view.addCharsAfterCursor @chars, {cursor: 'beforeEnd'}
    else if @type == Register.TYPES.ROWS
      row = @view.cursor.row
      parent = @view.data.getParent row
      index = @view.data.indexOf row

      if options.before
        @view.addBlocks @serialized_rows, parent, index, {cursor: 'first'}
      else
        children = @view.data.getChildren row
        if (not @view.data.collapsed row) and (children.length > 0)
          @view.addBlocks @serialized_rows, row, 0, {cursor: 'first'}
        else
          @view.addBlocks @serialized_rows ,parent, (index + 1), {cursor: 'first'}

# exports
module?.exports = Register
