class Data
  constructor: () ->

    @structure =
      0: # always the root node
        children: [1]
      1:
        children: []
        parent: 0

    @lines =
      0: [] # document title?
      1: []

    return @

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

    structure =
      0:
        children: []

    lines =
      0: []

    helper = (children, parentId) ->
      for child in children
        id++

        structure[id] =
          children: []
          parent: parentId
        structure[parentId].children.push id

        if typeof child == 'string'
          lines[id] = child.split ''
        else
          lines[id] = child.line.split ''
          helper child.children, id

    helper(serialized, 0)

    @structure = structure
    @lines = lines

module?.exports = Data
