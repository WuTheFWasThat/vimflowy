class Register

  #############
  # Union Type 
  #############

  @TYPES = {
    NONE: 0
    CHARS: 1
    # TODO: Document difference between ROWS and SERIALIZED ROWS
    ROWS: 2
    SERIALIZED_ROWS: 3
    CLONED_ROWS: 4
  }

  constructor: (view) ->
    @view = view
    do @saveNone
    return @

  saveNone: () ->
    @type = Register.TYPES.NONE
    @data = ''
  saveChars: (data) ->
    @type = Register.TYPES.CHARS
    @data = data
  saveRows: (data) ->
    @type = Register.TYPES.ROWS
    @data = data
  saveSerializedRows: (data) ->
    @type = Register.TYPES.SERIALIZED_ROWS
    @data = data
  saveClonedRows: (data) ->
    @type = Register.TYPES.CLONED_ROWS
    @data = data
  
  # Register is a union type. @data holds one of several values
  # They can be referenced as @rows etc.
  for type of Register.TYPES
    Object.defineProperty @prototype, type.toLowerCase(),
        get: -> @data
        set: (data) -> @data = data

  serialize: () ->
    return {type: @type, data: @data}

  deserialize: (serialized) ->
    @type = serialized.type
    @data = serialized.data

  ###########
  # Register 
  ###########

  paste: (options = {}) ->
    if @type == Register.TYPES.CHARS
      @pasteChars options
    else if @type == Register.TYPES.ROWS
      @pasteRows options
    else if @type == Register.TYPES.SERIALIZED_ROWS
      @pasteSerializedRows options
    else if @type == Register.TYPES.CLONED_ROWS
      #TODO: Implement
      console.log "CLONED_ROWS paste from register is not implemented"

  pasteChars: (options = {}) ->
    if options.before
      @view.addCharsAtCursor @chars, {cursor: options.cursor}
    else
      @view.addCharsAfterCursor @chars, {setCursor: 'end', cursor: options.cursor}

  pasteRows: (options = {}) ->
    # now that rows are in action, must switch to serialized version
    rows = @rows
    @saveSerializedRows (@view.data.serialize row for row in @rows)

    row = @view.cursor.row
    parent = @view.data.getParent row
    index = @view.data.indexOf row

    if options.before
      @view.attachBlocks rows, parent, index
    else
      children = @view.data.getChildren row
      if (not @view.data.collapsed row) and (children.length > 0)
        @view.attachBlocks rows, row, 0
      else
        @view.attachBlocks rows, parent, (index + 1)

    @view.cursor.set rows[0], 0

   pasteSerializedRows: (options = {}) ->
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
        @view.addBlocks @serialized_rows, parent, (index + 1), {setCursor: 'first'}

# exports
module?.exports = Register
