class Data
  root: 0

  constructor: () ->
    # defaults

    @structure =
      0: # always the root node
        children: [1]
        parent: 0
        collapsed: false
      1:
        children: []
        parent: 0
        collapsed: false

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

  setParent: (row, parent) ->
    @structure[row].parent = parent

  getChildren: (row) ->
    return @structure[row].children

  collapsed: (row) ->
    return @structure[row].collapsed

  # structure manipulation

  indexOf: (child) ->
    parent = @getParent child
    children = @getChildren parent
    return children.indexOf child

  detach: (id) ->
    parent = @getParent id
    index = @detachChild parent, id
    return {
      parent: parent
      index: index
    }

  detachChild: (id, child) ->
    children = @getChildren id
    i = children.indexOf child
    children.splice i, 1
    return i

  attachChild: (id, child, index = -1) ->
    @attachChildren id, [child], index

  attachChildren: (id, new_children, index = -1) ->
    children = @getChildren id
    if index == -1
      children.push.apply children, new_children
    else
      children.splice.apply children, [index, 0].concat(new_children)
    for child in new_children
      @setParent child, id

  nextVisible: (id) ->
    if not @collapsed id
      children = @getChildren id
      if children.length > 0
        return children[0]
    while true
      nextsib = @getSiblingAfter id
      if nextsib != null
        return nextsib
      id = @getParent id
      if id == @root
        return null

  # last thing visible nested within id
  lastVisible: (id) ->
    if @collapsed id
      return id
    children = @getChildren id
    if children.length > 0
      return @lastVisible children[children.length - 1]
    return id

  prevVisible: (id) ->
    prevsib = @getSiblingBefore id
    if prevsib != null
      return @lastVisible prevsib
    parent = @getParent id
    if parent == @root
      return null
    return parent

  getSiblingBefore: (id) ->
    return @_getSiblingOffset id, -1

  getSiblingAfter: (id) ->
    return @_getSiblingOffset id, 1

  _getSiblingOffset: (id, offset) ->
    if id == @root
      console.log 'Cannot get siblings of root'
      return null
    parent = @getParent id
    children = @getChildren parent
    index = (children.indexOf id) + offset
    if index >= children.length
      return null
    else if index < 0
      return null
    else
      return children[index]

  addChild: (id, index = -1) ->
    child = do @getId

    @lines[child] = []
    @structure[child] =
      collapsed: false
      children: []
      parent: id

    @attachChild id, child, index

    return child

  deleteRow: (id) ->
    if id == @root
      throw 'Cannot delete root'

    for child in @getChildren id
      @deleteRow child

    @detach id
    delete @structure[id]
    delete @lines[id]

  _insertSiblingHelper: (id, after) ->
    if id == @root
      console.log 'Cannot insert sibling of root'
      return null

    newId = do @getId
    parent = @getParent id
    children = @getChildren parent
    index = children.indexOf id

    return (@addChild parent, (index + after))

  insertSiblingAfter: (id) ->
    return @_insertSiblingHelper id, 1

  insertSiblingBefore: (id) ->
    return @_insertSiblingHelper id, 0

  # data manipulation

  writeChars: (row, col, chars) ->
    args = [col, 0].concat chars
    [].splice.apply @lines[row], args

  deleteChars: (row, col, num) ->
    removed = @lines[row].splice col, num
    return removed

  # important: serialized automatically garbage collects
  serialize: (id = @root) ->
    line = @lines[id].join('')
    if @structure[id].children.length
      children = (@serialize childid for childid in @getChildren id)
      struct = {
        line: line
        children: children
      }
      if @collapsed id
        struct.collapsed = true
      return struct
    else
      return line

  load: (serialized) ->
    id = 0

    structure = {}
    lines = {}

    helper = (my_id, my_serialized, parent_id) ->
      struct =
        children: []
        parent: parent_id

      if typeof my_serialized == 'string'
        lines[my_id] = my_serialized.split ''
      else
        lines[my_id] = my_serialized.line.split ''
        struct.collapsed = my_serialized.collapsed

        for child in my_serialized.children
          id++
          struct.children.push id
          helper id, child, my_id
      structure[my_id] = struct

    helper 0, serialized, 0

    @structure = structure
    @lines = lines

# exports
module?.exports = Data
