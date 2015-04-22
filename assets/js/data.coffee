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

  # data access

  getRow: (row) ->
    return @lines[row]

  getChar: (row, col) ->
    return @getRow(row)[col]

  rowLength: (row) ->
    return @getRow(row).length

  getParent: (row) ->
    return @structure[row].parent

  getChildren: (row) ->
    return @structure[row].children

  # structure manipulation

  getSiblingBefore: (id) ->
    return @_getSiblingOffset id, -1

  getSiblingAfter: (id) ->
    return @_getSiblingOffset id, 1

  _getSiblingOffset: (id, offset) ->
    if id == 0
      console.log 'Cannot get siblings of root'
      return id
    parent = @getParent id
    children = @getChildren parent
    index = (children.indexOf id) + offset
    if index >= children.length
      return id
    else if index < 0
      return id
    else
      return children[index]

  _insertSiblingHelper: (id, after) ->
    if id == 0
      console.log 'Cannot insert sibling of root'
      return

    newId = do @getId
    parent = @getParent id
    children = @getChildren parent
    index = children.indexOf id

    children.splice (index + after), 0, newId
    @lines[newId] = []
    @structure[newId] =
      children: []
      parent: parent
    return newId

  insertSiblingAfter: (id) ->
    return @_insertSiblingHelper id, 1

  insertSiblingBefore: (id) ->
    return @_insertSiblingHelper id, 0

  # returns next row
  deleteRow: (id) ->
    if id == 0
      console.log 'Cannot delete root'
      return 0

    for child in @getChildren id
      @deleteRow child
    parent = @getParent id
    parent_children = @getChildren parent

    index = parent_children.indexOf id
    parent_children.splice index, 1

    delete @structure[id]
    delete @lines[id]

    if index == parent_children.length
      if parent == 0
        # TODO: make new row
        return 0
      return parent
    else
      return parent_children[index]

  # data manipulation

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
