class Data
  root: 0

  constructor: (store) ->
    @store = store
    @viewRoot = do @store.getLastViewRoot
    return @

  changeViewRoot: (row) ->
    @viewRoot = row
    @store.setLastViewRoot row

  #########
  # lines #
  #########

  getLine: (row) ->
    return @store.getLine row

  getChar: (row, col) ->
    return @getLine(row)[col]

  writeChars: (row, col, chars) ->
    args = [col, 0].concat chars
    line = @getLine row
    [].splice.apply line, args
    @store.setLine row, line

  deleteChars: (row, col, num) ->
    line = @getLine row
    deleted = line.splice col, num
    @store.setLine row, line
    return deleted

  getLength: (row) ->
    return @getLine(row).length

  #############
  # structure #
  #############

  getParent: (row) ->
    return @store.getParent row

  getChildren: (row) ->
    return @store.getChildren row

  hasChildren: (row) ->
    return ((@getChildren row).length > 0)

  getSiblings: (row) ->
    parent = @getParent row
    return @getChildren parent

  collapsed: (row) ->
    return @store.getCollapsed row

  viewable: (row) -> # whether currently viewable
    return (not @collapsed row) or (row == @viewRoot)

  indexOf: (child) ->
    children = @getSiblings child
    return children.indexOf child

  detach: (id) ->
    parent = @getParent id
    children = @getChildren parent
    i = children.indexOf id
    children.splice i, 1

    @store.setChildren parent, children

    return {
      parent: parent
      index: i
    }


  attachChild: (id, child, index = -1) ->
    @attachChildren id, [child], index

  attachChildren: (id, new_children, index = -1) ->
    children = @getChildren id
    if index == -1
      children.push.apply children, new_children
    else
      children.splice.apply children, [index, 0].concat(new_children)
    for child in new_children
      @store.setParent child, id
    @store.setChildren id, children

  nextVisible: (id = @viewRoot) ->
    if @viewable id
      children = @getChildren id
      if children.length > 0
        return children[0]
    while true
      nextsib = @getSiblingAfter id
      if nextsib != null
        return nextsib
      id = @getParent id
      if id == @viewRoot
        return null

  # last thing visible nested within id
  lastVisible: (id = @viewRoot) ->
    if not @viewable id
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
    if parent == @viewRoot
      return null
    return parent

  # finds oldest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  oldestVisibleAncestor: (id) ->
    last = id
    while true
      cur = @getParent last
      if cur == @viewRoot
        return last
      if cur == @root
        return null
      last = cur

  # finds closest ancestor that is visible (viewRoot itself not considered visible)
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  youngestVisibleAncestor: (id) ->
    answer = id
    cur = id
    while true
      cur = @getParent cur
      if cur == @viewRoot
        return answer
      if cur == @root
        return null
      if @collapsed cur
        answer = cur

  toggleCollapsed: (id) ->
    @store.setCollapsed id, (not @collapsed id)

  getSiblingBefore: (id) ->
    return @getSiblingOffset id, -1

  getSiblingAfter: (id) ->
    return @getSiblingOffset id, 1

  getSiblingOffset: (id, offset) ->
    return (@getSiblingRange id, offset, offset)[0]

  getSiblingRange: (id, min_offset, max_offset) ->
    children = @getSiblings id
    index = @indexOf id
    return @getChildRange (@getParent id), (min_offset + index), (max_offset + index)

  getChildRange: (id, min, max) ->
    children = @getChildren id
    indices = [min..max]

    return indices.map (index) ->
      if index >= children.length
        return null
      else if index < 0
        return null
      else
        return children[index]

  addChild: (id, index = -1) ->
    child = do @store.getNew
    @attachChild id, child, index
    return child

  # this is never used, since data structure is basically persistent
  # deleteRow: (id) ->
  #   if id == @viewRoot
  #     throw 'Cannot delete view root'

  #   for child in (@getChildren id).slice()
  #     @deleteRow child

  #   @detach id
  #   @store.delete id

  _insertSiblingHelper: (id, after) ->
    if id == @viewRoot
      console.log 'Cannot insert sibling of view root'
      return null

    parent = @getParent id
    children = @getChildren parent
    index = children.indexOf id

    return (@addChild parent, (index + after))

  insertSiblingAfter: (id) ->
    return @_insertSiblingHelper id, 1

  insertSiblingBefore: (id) ->
    return @_insertSiblingHelper id, 0

  orderedLines: () ->
    ids = []

    helper = (id) =>
      ids.push id
      for child in @getChildren id
        helper child
    helper @root
    return ids

  find: (chars, nresults = 10) ->
    results = [] # list of (row_id, index) pairs
    if chars.length == 0
      return results

    for id in do @orderedLines
      line = @getLine id
      for i in [0..line.length-chars.length]
        match = true
        for j in [0...chars.length]
          if line[i+j] != chars[j]
            match = false
            break
        if match
          results.push {
            row: id
            index: i
          }
          break
      if nresults > 0 and results.length == nresults
        break
    return results

  #########
  # marks #
  #########

  getMark: (id) ->
    return @store.getMark id

  setMark: (id, mark = '') ->
    oldmark = @store.getMark id

    allMarks = do @store.getAllMarks
    if mark
      allMarks[mark] = id
    if oldmark
      delete allMarks[oldmark]
    @store.setAllMarks allMarks

    @store.setMark id, mark

  getAllMarks: () ->
    return do @store.getAllMarks

  #################
  # serialization #
  #################

  # important: serialized automatically garbage collects
  serialize: (id = @root, pretty=false) ->
    line = (@getLine id).join('')

    children = (@serialize childid, pretty for childid in @getChildren id)
    struct = {
      line: line
      children: children
    }

    if id == @root and @viewRoot != @root
      struct.viewRoot = @viewRoot

    if @collapsed id
      struct.collapsed = true

    mark = @store.getMark id
    if mark
      struct.mark = mark

    if pretty
      if children.length == 0 and not mark
        return line
    return struct

  loadTo: (serialized, parent = @root, index = -1) ->
    id = do @store.getNew

    if id != @root
      @attachChild parent, id, index
    else
      # parent should be 0
      @store.setParent id, @root

    if typeof serialized == 'string'
      @store.setLine id, (serialized.split '')
    else
      @store.setLine id, (serialized.line.split '')
      @store.setCollapsed id, serialized.collapsed

      if serialized.mark
        @setMark id, serialized.mark

      for serialized_child in serialized.children
        @loadTo serialized_child, id

    return id

  load: (serialized) ->
    if serialized.viewRoot
      @viewRoot = serialized.viewRoot
    else
      @viewRoot = @root

    @loadTo serialized

# exports
module?.exports = Data
