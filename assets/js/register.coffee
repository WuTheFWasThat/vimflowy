class Register
  TYPES = {
    NONE: 0
    CHARS: 1
    LINES: 2
  }

  constructor: (view) ->
    @view = view
    @type = TYPES.NONE
    return @

  saveChars: (chars) ->
    @type = TYPES.CHARS
    @chars = chars

  saveLines: (lines) ->
    # lines: array of row IDs

    @type = TYPES.LINES
    @lines = lines

  paste: (options) ->
    if @type == TYPES.CHARS
      return @view.addCharsAfterCursor @chars
    else if @type == TYPES.LINES
      return

# exports
module?.exports = Register
