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

# exports
module?.exports = Register
