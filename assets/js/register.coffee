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

  constructor: (session) ->
    @session = session
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
      @session.addCharsAtCursor @chars
    else
      @session.addCharsAfterCursor @chars
      @session.cursor.setCol (@session.cursor.col + @chars.length)

  pasteSerializedRows: (options = {}) ->
    path = @session.cursor.path
    parent = path.parent
    index = @session.document.indexOf path

    if options.before
      @session.addBlocks parent, index, @serialized_rows, {setCursor: 'first'}
    else
      children = @session.document.getChildren path
      if (not @session.document.collapsed path.row) and (children.length > 0)
        @session.addBlocks path, 0, @serialized_rows, {setCursor: 'first'}
      else
        @session.addBlocks parent, (index + 1), @serialized_rows, {setCursor: 'first'}

  pasteClonedRows: (options = {}) ->
    path = @session.cursor.path
    parent = path.parent
    index = @session.document.indexOf path

    if options.before
      @session.attachBlocks parent, @cloned_rows, index, {setCursor: 'first'}
    else
      children = @session.document.getChildren path
      if (not @session.document.collapsed path.row) and (children.length > 0)
        @session.attachBlocks path, @cloned_rows, 0, {setCursor: 'first'}
      else
        @session.attachBlocks parent, @cloned_rows, (index + 1), {setCursor: 'first'}

# exports
module.exports = Register
