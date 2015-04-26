class Data
  root = 0

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
  removeChild: (id, child) ->
    children = @getChildren id
    i = children.indexOf child
    children.splice i, 1
    return i

  addChild: (id, child, index = -1) ->
    children = @getChildren id
    if index == -1
      children.push child
    else
      children.splice index, 0, child
    @setParent child, id

  indent: (id, options = {}) ->
    sib = @getSiblingBefore id
    if sib == null
      return null # cannot indent

    @removeChild (@getParent id), id
    @addChild sib, id

    if not options.recursive
      for child in (@getChildren id).slice()
        @removeChild id, child
        @addChild sib, child

    return sib

  unindent: (id, options = {}) ->
    if not options.recursive
      if (@getChildren id).length > 0
        return

    parent = @getParent id
    if parent == root
      return

    p_i = @removeChild parent, id

    newparent = @getParent parent

    pp_i = (@getChildren newparent).indexOf parent
    @addChild newparent, id, (pp_i+1)

    if not options.recursive
      p_children = @getChildren parent
      for child in p_children.slice(p_i)
        @removeChild parent, child
        @addChild id, child

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
      if id == root
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
    if parent == root
      return null
    return parent

  getSiblingBefore: (id) ->
    return @_getSiblingOffset id, -1

  getSiblingAfter: (id) ->
    return @_getSiblingOffset id, 1

  _getSiblingOffset: (id, offset) ->
    if id == root
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

  _insertSiblingHelper: (id, after) ->
    if id == root
      console.log 'Cannot insert sibling of root'
      return null

    newId = do @getId
    parent = @getParent id
    children = @getChildren parent
    index = children.indexOf id

    children.splice (index + after), 0, newId
    @lines[newId] = []
    @structure[newId] =
      collapsed: false
      children: []
      parent: parent
    return newId

  insertSiblingAfter: (id) ->
    return @_insertSiblingHelper id, 1

  insertSiblingBefore: (id) ->
    return @_insertSiblingHelper id, 0

  # returns next row
  deleteRow: (id) ->
    if id == root
      console.log 'Cannot delete root'
      return id

    for child in @getChildren id
      @deleteRow child
    parent = @getParent id
    parent_children = @getChildren parent

    index = parent_children.indexOf id
    parent_children.splice index, 1

    delete @structure[id]
    delete @lines[id]

    if index == parent_children.length
      if parent == root
        # TODO: make new row
        return id
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

  serialize: (id = root) ->
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
