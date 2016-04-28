###
Represents a yank register.  Holds saved data of one of several types -
either nothing, a set of characters, a set of row ids, or a set of serialized rows
Implements pasting for each of the types
###

class Register

  @TYPES = {
    NONE: 0
    CHARS: 1
    SERIALIZED_ROWS: 2
    CLONED_ROWS: 3
  }

  # Register is a union type. @saved holds one of several kinds of values
  # They can be referenced as @chars, @rows etc.
  for type of Register.TYPES
    Object.defineProperty @prototype, type.toLowerCase(),
        get: -> @saved
        set: (save) -> @saved = save

  constructor: (view) ->
    @view = view
    do @saveNone
    return @

  saveNone: () ->
    @type = Register.TYPES.NONE
    @saved = null

  saveChars: (save) ->
    @type = Register.TYPES.CHARS
    @saved = save

  saveSerializedRows: (save) ->
    @type = Register.TYPES.SERIALIZED_ROWS
    @saved = save

  saveClonedRows: (save) ->
    @type = Register.TYPES.CLONED_ROWS
    @saved = save

  serialize: () ->
    return {type: @type, saved: @saved}

  deserialize: (serialized) ->
    @type = serialized.type
    @saved = serialized.saved

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
    index = @view.document.indexOf row

    if options.before
      @view.addBlocks parent, index, @serialized_rows, {setCursor: 'first'}
    else
      children = @view.document.getChildren row
      if (not @view.document.collapsed row) and (children.length > 0)
        @view.addBlocks row, 0, @serialized_rows, {setCursor: 'first'}
      else
        @view.addBlocks parent, (index + 1), @serialized_rows, {setCursor: 'first'}

  pasteClonedRows: (options = {}) ->
    row = @view.cursor.row
    parent = do row.getParent
    index = @view.document.indexOf row

    if options.before
      @view.attachBlocks parent, @cloned_rows, index, {setCursor: 'first'}
    else
      children = @view.document.getChildren row
      if (not @view.document.collapsed row) and (children.length > 0)
        @view.attachBlocks row, @cloned_rows, 0, {setCursor: 'first'}
      else
        @view.attachBlocks parent, @cloned_rows, (index + 1), {setCursor: 'first'}

# exports
module?.exports = Register
window?.Register = Register
