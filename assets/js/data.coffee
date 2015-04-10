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
    args = [col, 0].concat chars
    [].splice.apply @lines[row], args

  deleteChars: (row, col, num) ->
    removed = @lines[row].splice col, num
    return removed

  serialize: () ->
    return {
      structure: @structure
      lines: @lines
    }

  load: (serialized) ->
    @structure = serialized.structure
    @lines = serialized.lines

