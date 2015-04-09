class Data
  constructor: () ->

    @structure = [
      {
        id: 0
      }
    ]
    @lines = {
      0: []
    }

    @history = []
    @historyIndex = 0
    return @

  writeChars: (row, col, chars) ->
    args = [col, 0].concat do chars.split
    [].splice.apply @lines[row], args

  deleteChars: (row, col, num) ->
    @lines[row].splice col, num

  serialize: () ->
    return {
      structure: @structure
      lines: @lines
    }

  load: (serialized) ->
    @structure = serialized.structure
    @lines = serialized.lines

