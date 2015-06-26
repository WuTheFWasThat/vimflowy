class Data
  root: 0

  constructor: (store) ->
    @store = store
    # defaults

    # default document: a single blank line
    @viewRoot = 0
    return @

  registerSettings: (settings) -> # Otherwise a circular dependency
    @settings = settings

  changeViewRoot: (row) ->
    @viewRoot = row

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

  ############
  # settings #
  ############

  getSetting: (setting) ->
    return @store.getSetting setting

  setSetting: (setting, value) ->
    return @store.setSetting setting, value

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

  # important: serialized automatically garbage collects
  serialize: (id = @root) ->
    line = (@getLine id).join('')
    if @hasChildren id
      children = (@serialize childid for childid in @getChildren id)
      struct = {
        line: line
        children: children
      }
      if id == @root and @viewRoot != @root
        struct.viewRoot = @viewRoot
      if @collapsed id
        struct.collapsed = true
      return struct
    else
      return line

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

      for serialized_child in serialized.children
        @loadTo serialized_child, id

    return id

  load: (serialized) ->
    if serialized.viewRoot
      @viewRoot = serialized.viewRoot
    else
      @viewRoot = @root

    @loadTo serialized

  export: (filename, mimetype) ->
    filename ||= @settings?.getSetting?('export_filename') || 'vimflowy.json'
    if not mimetype? # Infer mimetype from file extension
        mimetype = @mimetypeLookup filename
    content = @exportContent mimetype
    @saveFile filename, mimetype, content
  exportContent: (mimetype) ->
    jsonContent = do @serialize
    if mimetype == 'application/json'
        delete jsonContent.viewRoot
        return JSON.stringify(jsonContent, undefined, 2)
    else if mimetype == 'text/plain'
        # Workflowy compatible plaintext export
        #   Ignores 'collapsed' and viewRoot
        indent = "  "
        exportLines = (node) ->
            if typeof(node) == 'string'
              return ["- #{node}"]
            lines = []
            lines.push "- #{node.line}"
            for child in node.children ? []
                for line in exportLines child
                    lines.push "#{indent}#{line}"
            return lines
        return(exportLines jsonContent).join "\n"
    else
        throw "Invalid export format"
   mimetypeLookup: (filename) ->
     parts = filename.split '.'
     extension = parts[parts.length - 1] ? ''
     extensionLookup =
       'json': 'application/json'
       'txt': 'text/plain'
       '': 'text/plain'
     return extensionLookup[extension.toLowerCase()]

  saveFile: (filename, mimetype, content) ->
    if not $?
      throw "Tried to save a file from the console, impossible"
    $("#export").attr("download", filename)
    $("#export").attr("href", "data: #{mimetype};charset=utf-8,#{encodeURIComponent(content)}")
    $("#export")[0].click()
    $("#export").attr("download", null)
    $("#export").attr("href", null)
    return content

# exports
module?.exports = Data
