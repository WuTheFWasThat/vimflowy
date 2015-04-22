class Data
  constructor: () ->
    # defaults

    @structure =
      0: # always the root node
        children: [1]
        parent: 0
      1:
        children: []
        parent: 0

    @lines =
      0: [] # document title?
      1: []

    return @

  getId: () ->
    id = 0
    while @lines[id]
      id++
    return id

  rowLength: (row) ->
    return @lines[row].length

  getChar: (row, col) ->
    return @lines[row][col]

  insertSiblingAfter: (id) ->
    newId = getId()
    return

  writeChars: (row, col, chars) ->
    args = [col, 0].concat chars
    [].splice.apply @lines[row], args

  deleteChars: (row, col, num) ->
    removed = @lines[row].splice col, num
    return removed

  serialize: (id = 0) ->
    line = @lines[id].join('')
    if @structure[id].children.length
      children = (@serialize childid for childid in @structure[id].children)
      return {
        line: line
        children: children
      }
    else
      return line

  load: (serialized) ->
    id = 0

    structure = {}
    lines = {}

    helper = (my_id, my_serialized, parent_id) ->
      structure[my_id] =
        children: []
        parent: parent_id

      if typeof my_serialized == 'string'
        lines[my_id] = my_serialized.split ''
      else
        lines[my_id] = my_serialized.line.split ''

        for child in my_serialized.children
          id++
          structure[my_id].children.push id
          helper id, child, my_id

    helper 0, serialized, 0

    @structure = structure
    @lines = lines

# exports
module?.exports = Data
