###
Represents a yank register.  Holds data of one of several types -
either nothing, a set of characters, a set of row ids, or a set of serialized rows
Implements pasting for each of the types
###

class Register

  @TYPES = {
    NONE: 0
    CHARS: 1
    ROWS: 2
    SERIALIZED_ROWS: 3
    CLONED_ROWS: 4
  }

  # Register is a union type. @data holds one of several kinds of values
  # They can be referenced as @chars, @rows etc.
  for type of Register.TYPES
    Object.defineProperty @prototype, type.toLowerCase(),
        get: -> @data
        set: (data) -> @data = data

  constructor: (view) ->
    @view = view
    do @saveNone
    return @

  saveNone: () ->
    @type = Register.TYPES.NONE
    @data = null

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

  serialize: () ->
    return {type: @type, data: @data}

  deserialize: (serialized) ->
    @type = serialized.type
    @data = serialized.data

  ###########
  # Pasting
  ###########

  paste: (options = {}) ->
    if @type == Register.TYPES.CHARS
      @pasteChars options
    else if @type == Register.TYPES.ROWS
      @pasteRows options
    else if @type == Register.TYPES.SERIALIZED_ROWS
      @pasteSerializedRows options
    else if @type == Register.TYPES.CLONED_ROWS
      @pasteClonedRows options

  pasteChars: (options = {}) ->
    if options.before
      @view.addCharsAtCursor @chars, {cursor: options.cursor}
    else
      @view.addCharsAfterCursor @chars, {setCursor: 'end', cursor: options.cursor}

  pasteRows: (options = {}) ->
    row = @view.cursor.row
    parent = do row.getParent
    index = @view.data.indexOf row

    if options.before
      @view.attachBlocks @rows, parent, index
    else
      children = @view.data.getChildren row
      if (not @view.data.collapsed row) and (children.length > 0)
        @view.attachBlocks @rows, row, 0
      else
        @view.attachBlocks @rows, parent, (index + 1)

    @view.cursor.set @rows[0], 0

    # now that rows are in action, must switch to serialized version
    # @saveSerializedRows (@view.data.serialize row for row in @rows)
    # For efficiency, just wipe registers for now
    do @saveNone

  pasteSerializedRows: (options = {}) ->
    row = @view.cursor.row
    parent = do row.getParent
    index = @view.data.indexOf row

    if options.before
      @view.addBlocks @serialized_rows, parent, index, {setCursor: 'first'}
    else
      children = @view.data.getChildren row
      if (not @view.data.collapsed row) and (children.length > 0)
        @view.addBlocks @serialized_rows, row, 0, {setCursor: 'first'}
      else
        @view.addBlocks @serialized_rows, parent, (index + 1), {setCursor: 'first'}

  pasteClonedRows: (options = {}) ->
    row = @view.cursor.row
    parent = do row.getParent
    index = @view.data.indexOf row

    if options.before
      @view.addClones @cloned_rows, parent, index, {setCursor: 'first'}
    else
      children = @view.data.getChildren row
      if (not @view.data.collapsed row) and (children.length > 0)
        @view.addClones @cloned_rows, row, 0, {setCursor: 'first'}
      else
        @view.addClones @cloned_rows, parent, (index + 1), {setCursor: 'first'}

# exports
module?.exports = Register
window?.Register = Register
