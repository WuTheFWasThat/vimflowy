class Register
  @TYPES = {
    NONE: 0
    CHARS: 1
    ROWS: 2
    SERIALIZED_ROWS: 3
  }

  constructor: (view) ->
    @view = view
    @type = Register.TYPES.NONE
    return @

  saveChars: (chars) ->
    @type = Register.TYPES.CHARS
    @chars = chars

  saveSerializedRows: (serialized_rows) ->
    @type = Register.TYPES.SERIALIZED_ROWS
    @serialized_rows = serialized_rows

  saveRows: (rows) ->
    @type = Register.TYPES.ROWS
    @rows = rows

  serialize: () ->
    data = ''
    if @type == Register.TYPES.CHARS
      data = @chars
    else if @type == Register.TYPES.ROWS
      data = [@view.data.serialize row for row in @rows]
    else if @type == Register.TYPES.SERIALIZED_ROWS
      data = @serialized_rows
    return {type: @type, data: data}

  deserialize: (serialized) ->
    @type = serialized.type
    if @type == Register.TYPES.CHARS
      @chars = serialized.data
    else if @type == Register.TYPES.ROWS
      @serialized_rows = serialized.data
    else if @type == Register.TYPES.SERIALIZED_ROWS
      @serialized_rows = serialized.data

  paste: (options = {}) ->
    if @type == Register.TYPES.CHARS
      if options.before
        @view.addCharsAtCursor @chars, {cursor: options.cursor}
      else
        @view.addCharsAfterCursor @chars, {setCursor: 'end', cursor: options.cursor}
    else if @type == Register.TYPES.ROWS
      row = @view.cursor.row
      parent = @view.data.getParent row
      index = @view.data.indexOf row

      if options.before
        @view.attachBlocks @rows, parent, index
      else
        children = @view.data.getChildren row
        if (not @view.data.collapsed row) and (children.length > 0)
          @view.attachBlocks @rows, row, 0
        else
          @view.attachBlocks @rows ,parent, (index + 1)

      @view.cursor.set @rows[0], 0

      # now that rows are in action, must switch to serialized version
      @saveSerializedRows (@view.data.serialize row for row in @rows)
    else if @type == Register.TYPES.SERIALIZED_ROWS
      row = @view.cursor.row
      parent = @view.data.getParent row
      index = @view.data.indexOf row

      if options.before
        @view.addBlocks @serialized_rows, parent, index, {setCursor: 'first'}
      else
        children = @view.data.getChildren row
        if (not @view.data.collapsed row) and (children.length > 0)
          @view.addBlocks @serialized_rows, row, 0, {setCursor: 'first'}
        else
          @view.addBlocks @serialized_rows ,parent, (index + 1), {setCursor: 'first'}

# exports
module?.exports = Register
