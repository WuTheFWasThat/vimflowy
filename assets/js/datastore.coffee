class InMemoryDataStore
  constructor: () ->
    @structure = {}
    @lines = {}
    return

  getLine: (row) ->
    return [].slice.apply @lines[row]

  setLine: (row, line) ->
    @lines[row] = line

  getParent: (row) ->
    return @structure[row].parent

  setParent: (row, parent) ->
    @structure[row].parent = parent

  getChildren: (row) ->
    return [].slice.apply @structure[row].children

  setChildren: (row, children) ->
    @structure[row].children = children

  getCollapsed: (row) ->
    return @structure[row].collapsed

  setCollapsed: (row, collapsed) ->
    @structure[row].collapsed = collapsed

  getId: () ->
    id = 0
    while @lines[id]
      id++
    return id

  getNew: () ->
    id = do @getId

    @lines[id] = []
    @structure[id] =
      collapsed: false
      children: []
      parent: null
    return id

  # delete: (id) ->
  #   delete @structure[id]
  #   delete @lines[id]

module?.exports = {
  InMemoryDataStore: InMemoryDataStore
}
