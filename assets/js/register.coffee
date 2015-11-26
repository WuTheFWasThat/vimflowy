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
    else if @type == Register.TYPES.SERIALIZED_ROWS
      @pasteSerializedRows options
    else if @type == Register.TYPES.CLONED_ROWS
      @pasteClonedRows options

  pasteChars: (options = {}) ->
    if options.before
      @view.addCharsAtCursor @chars, {cursor: options.cursor}
    else
      @view.addCharsAfterCursor @chars, {setCursor: 'end', cursor: options.cursor}

  pasteSerializedRows: (options = {}) ->
    row = @view.cursor.row
    parent = do row.getParent
    index = @view.data.indexOf row

    if options.before
      @view.addBlocks parent, index, @serialized_rows, {setCursor: 'first'}
    else
      children = @view.data.getChildren row
      if (not @view.data.collapsed row) and (children.length > 0)
        @view.addBlocks row, 0, @serialized_rows, {setCursor: 'first'}
      else
        @view.addBlocks parent, (index + 1), @serialized_rows, {setCursor: 'first'}

  pasteClonedRows: (options = {}) ->
    row = @view.cursor.row
    parent = do row.getParent
    index = @view.data.indexOf row

    if options.before
      @view._attachBlocks parent, @cloned_rows, index, {setCursor: 'first'}
    else
      children = @view.data.getChildren row
      if (not @view.data.collapsed row) and (children.length > 0)
        @view._attachBlocks row, @cloned_rows, 0, {setCursor: 'first'}
      else
        @view._attachBlocks parent, @cloned_rows, (index + 1), {setCursor: 'first'}

# exports
module?.exports = Register
window?.Register = Register
