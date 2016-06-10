_ = require 'lodash'

mutations = require './mutations.coffee'
constants = require './constants.coffee'
utils = require './utils.coffee'
errors = require './errors.coffee'
Cursor = require './cursor.coffee'
Register = require './register.coffee'
Logger = require './logger.coffee'
EventEmitter = require './eventEmitter.coffee'

Modes = require './modes.coffee'
MODES = Modes.modes

DocumentLib = require './document.coffee'
Path = DocumentLib.Path

###
a Session represents a session with a vimflowy document
It holds a Cursor, a Document object, and a Settings object
It exposes methods for manipulation of the document, and movement of the cursor

Currently, the separation between the Session and Document classes is not very good.  (see document.coffee)
Ideally, session shouldn't do much more than handle cursors and history
###

class Session extends EventEmitter
  constructor: (doc, options = {}) ->
    super

    @document = doc

    @bindings = options.bindings
    @settings = options.settings
    # session needs to know div for page scrolling, getting visible rows
    @mainDiv = options.mainDiv
    @messageDiv = options.messageDiv
    @menuDiv = options.menuDiv

    @register = new Register @

    # TODO: if we ever support multi-user case, ensure last view root is valid
    @viewRoot = Path.loadFromAncestry (do @document.store.getLastViewRoot || [])
    if not (@document.hasChildren @document.root)
      @document.load constants.empty_data

    if @viewRoot.is @document.root
      row = (@document.getChildren @viewRoot)[0]
    else
      row = @viewRoot
    @cursor = new Cursor @, row, 0

    do @reset_history
    do @reset_jump_history

    @setMode MODES.NORMAL
    return @

  exit: () ->
    @emit "exit"

  #################
  # modes related
  #################

  setMode: (newmode) ->
    if newmode == @mode
      return

    oldmode = @mode
    if oldmode
      (Modes.getMode oldmode).exit @, newmode

    @mode = newmode
    (Modes.getMode @mode).enter @, oldmode

    @emit 'modeChange', oldmode, newmode

  toggleBindingsDiv: () ->
    @emit 'toggleBindingsDiv'

  #################
  # show message
  #################

  showMessage: (message, options = {}) ->
    options.time ?= 5000
    Logger.logger.info "Showing message: #{message}"
    if @messageDiv
      clearTimeout @messageDivTimeout

      @messageDiv.text(message)
      if options.text_class
        @messageDiv.addClass("text-#{options.text_class}")

      @messageDivTimeout = setTimeout (() =>
        @messageDiv.text('')
        @messageDiv.removeClass()
      ), options.time

  #################
  # import/export #
  #################

  parseJson: (content) ->
    try
      root = JSON.parse(content)
    catch
      @showMessage "The uploaded file is not valid JSON", {text_class: 'error'}
      return false
    verify = (node) ->
      if node.clone
        return true
      unless node.text || node.text == '' then return false
      if node.children
        for child in node.children
          unless verify child then return false
      return true
    unless verify root
      @showMessage "The uploaded file is not in a valid vimflowy format", {text_class: 'error'}
      return false
    return root

  parsePlaintext: (content) ->
    # Step 1: parse into (int, string) pairs of indentation amounts.
    lines = []
    for line in content.split "\n"
      if line.match /^\s*".*"$/ # Flag workflowy annotations as special cases
        lines.push
          indent: (line.match whitespace)[0].length
          line: line.replace /^\s*"(.*)"$/, "$1"
          annotation: true
        continue
      whitespace = /^\s*/
      # TODO: record whether COMPLETE and strikethrough line if so?
      lines.push
        indent: (line.match whitespace)[0].length
        line: (line.replace whitespace, "").replace /^(?:-\s*)?(?:\[COMPLETE\] )?/, ""
    while lines[lines.length-1].line == '' # Strip trailing blank line(s)
      lines = lines.splice(0, lines.length-1)

    # Step 2: convert a list of (int, string, annotation?) into a forest format
    parseAllChildren = (parentIndentation, lineNumber) ->
      children = []
      if lineNumber < lines.length and lines[lineNumber].annotation # Each node can have an annotation immediately follow it
        children.push
          text: lines[lineNumber].line
        lineNumber = lineNumber + 1
      while lineNumber < lines.length and lines[lineNumber].indent > parentIndentation # For [the first line of] each child
        child =
          text: lines[lineNumber].line
        result = parseAllChildren lines[lineNumber].indent, lineNumber + 1
        lineNumber = result.lineNumber
        if result.children?
          child.children = result.children
          child.collapsed = result.children.length > 0
        children.push child
      return { children: children, lineNumber: lineNumber}
    forest = (parseAllChildren -1, 0).children
    root =
      text: ""
      children: forest
      collapsed: (forest.length > 0)
    return root

  parseContent: (content, mimetype) ->
    if mimetype in ['application/json']
      return @parseJson content
    else if mimetype in ['text/plain', 'Text']
      return @parsePlaintext content
    else
      return null

  # TODO: make this use replace_empty = true?
  importContent: (content, mimetype) ->
    root = @parseContent content, mimetype
    if not root then return false
    row = @cursor.row
    if root.text == '' && root.children # Complete export, not one node
      @addBlocks row, 0, root.children
    else
      @addBlocks row, 0, [root]
    do @save
    @emit 'importFinished'
    return true

  exportContent: (mimetype) ->
    jsonContent = do @document.serialize
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
        lines.push "- #{node.text}"
        for child in node.children ? []
          if child.clone
            continue
          for line in exportLines child
            lines.push "#{indent}#{line}"
        return lines
      return (exportLines jsonContent).join "\n"
    else
      throw new errors.UnexpectedValue "mimetype", mimetype

  #################
  # MUTATIONS
  #################

  reset_history: () ->
    @mutations = [] # full mutation history
    @history = [{
      index: 0
    }]
    @historyIndex = 0 # index into indices

  save: () ->
    if @historyIndex != @history.length - 1
      # haven't acted, otherwise would've sliced
      return
    if @history[@historyIndex].index == @mutations.length
      # haven't acted, otherwise there would be more mutations
      return

    state = @history[@historyIndex]
    state.after = {
      cursor: do @cursor.clone
      viewRoot: @viewRoot
    }

    @historyIndex += 1
    @history.push {
      index: @mutations.length
    }

  restoreViewState: (state) ->
    @cursor.from state.cursor
    if @mode != MODES.INSERT
      do @cursor.backIfNeeded
    @changeView state.viewRoot

  undo: () ->
    if @historyIndex > 0
      oldState = @history[@historyIndex]
      @historyIndex -= 1
      newState = @history[@historyIndex]

      Logger.logger.debug "UNDOING ("
      for i in [(oldState.index-1)...(newState.index-1)]
        mutation = @mutations[i]
        Logger.logger.debug "  Undoing mutation #{mutation.constructor.name}(#{mutation.str()})"
        mutation.rewind @
      Logger.logger.debug ") END UNDO"
      @restoreViewState newState.before

  redo: () ->
    if @historyIndex < @history.length - 1
      oldState = @history[@historyIndex]
      @historyIndex += 1
      newState = @history[@historyIndex]

      Logger.logger.debug "REDOING ("
      for i in [oldState.index...newState.index]
        mutation = @mutations[i]
        Logger.logger.debug "  Redoing mutation #{mutation.constructor.name}(#{mutation.str()})"
        if not mutation.validate @
          # this should not happen, since the state should be the same as before
          throw new errors.GenericError "Failed to redo mutation: #{mutation.str()}"
        mutation.remutate @
      Logger.logger.debug ") END REDO"
      @restoreViewState oldState.after

  do: (mutation) ->
    if not @history
      # NOTE: we let mutations through since some plugins may apply mutations on load
      # these mutations won't be undoable, which is desired
      Logger.logger.warn "Tried mutation #{mutation} before init!"
      mutation.mutate @
      return true

    if @historyIndex != @history.length - 1
      @history = @history.slice 0, (@historyIndex + 1)
      @mutations = @mutations.slice 0, @history[@historyIndex].index

    state = @history[@historyIndex]
    if @mutations.length == state.index
      state.before = {
        cursor: do @cursor.clone
        viewRoot: @viewRoot
      }

    Logger.logger.debug "Applying mutation #{mutation.constructor.name}(#{mutation.str()})"
    if not mutation.validate @
      return false
    mutation.mutate @
    @mutations.push mutation
    return true

  ##################
  # viewability
  ##################

  # whether currently viewable.  ASSUMES ROW IS WITHIN VIEWROOT
  viewable: (row) ->
    return (not @document.collapsed row.id) or (row.is @viewRoot)

  nextVisible: (row) ->
    if @viewable row
      children = @document.getChildren row
      if children.length > 0
        return children[0]
    if row.is @viewRoot
      return null
    while true
      nextsib = @document.getSiblingAfter row
      if nextsib?
        return nextsib
      row = do row.getParent
      if row.is @viewRoot
        return null

  # last thing visible nested within id
  lastVisible: (row = @viewRoot) ->
    if not @viewable row
      return row
    children = @document.getChildren row
    if children.length > 0
      return @lastVisible children[children.length - 1]
    return row

  prevVisible: (row) ->
    if row.is @viewRoot
      return null
    prevsib = @document.getSiblingBefore row
    if prevsib?
      return @lastVisible prevsib
    parent = do row.getParent
    if parent.is @viewRoot
      if parent.is @document.root
        return null
      else
        return @viewRoot
    return parent

  # finds oldest ancestor that is visible *besides viewRoot*
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  oldestVisibleAncestor: (row) ->
    last = row
    while true
      cur = do last.getParent
      if cur.is @viewRoot
        return last
      if do cur.isRoot
        return null
      last = cur

  # finds closest ancestor that is visible
  # returns null if there is no visible ancestor (i.e. viewroot doesn't contain row)
  youngestVisibleAncestor: (row) ->
    answer = row
    cur = row
    while true
      if cur.is @viewRoot
        return answer
      if do cur.isRoot
        return null
      if @document.collapsed cur.id
        answer = cur
      cur = do cur.getParent

  isVisible: (row) ->
    visibleAncestor = @youngestVisibleAncestor row
    (visibleAncestor != null) and (row.is visibleAncestor)


  ##################
  # View root
  ##################

  _changeViewRoot: (row) ->
    @viewRoot = row
    @document.store.setLastViewRoot do row.getAncestry

  reset_jump_history: () ->
    @jumpHistory = [{
      viewRoot: @viewRoot
      cursor_before: do @cursor.clone
    }]
    @jumpIndex = 0 # index into jump history

  addToJumpHistory: (jump_fn) ->
    jump = @jumpHistory[@jumpIndex]
    jump.cursor_after = do @cursor.clone

    @jumpHistory = @jumpHistory.slice 0, (@jumpIndex+1)

    do jump_fn

    @jumpHistory.push {
      viewRoot: @viewRoot
      cursor_before: do @cursor.clone
    }
    @jumpIndex += 1

  # try going to jump, return true if succeeds
  tryJump: (jump) ->
    if jump.viewRoot.id == @viewRoot.id
      return false # not moving, don't jump

    if not @document.isAttached jump.viewRoot.id
      return false # invalid location

    children = @document.getChildren jump.viewRoot

    @_changeViewRoot jump.viewRoot
    if children.length
      @cursor.setRow children[0]
    else
      @cursor.setRow jump.viewRoot

    if @document.isAttached jump.cursor_after.row.id
      # if the row is attached and under the view root, switch to it
      cursor_row = @youngestVisibleAncestor jump.cursor_after.row
      if cursor_row != null
        @cursor.setRow cursor_row
    return true

  jumpPrevious: () ->
    jumpIndex = @jumpIndex

    jump = @jumpHistory[jumpIndex]
    jump.cursor_after = do @cursor.clone

    while true
      if jumpIndex == 0
        return false
      jumpIndex -= 1
      oldjump = @jumpHistory[jumpIndex]
      if @tryJump oldjump
        @jumpIndex = jumpIndex
        return true

  jumpNext: () ->
    jumpIndex = @jumpIndex

    jump = @jumpHistory[jumpIndex]
    jump.cursor_after = do @cursor.clone

    while true
      if jumpIndex == @jumpHistory.length - 1
        return false
      jumpIndex += 1
      newjump = @jumpHistory[jumpIndex]
      if @tryJump newjump
        @jumpIndex = jumpIndex
        return true

  # try to change the view root to row
  # fails if there is no child
  # records in jump history
  changeView: (row) ->
    if row.id == @viewRoot.id
      return # not moving, do nothing
    @addToJumpHistory () =>
      @_changeViewRoot row

  # try to zoom into newroot, updating the cursor
  zoomInto: (newroot) ->
    @changeView newroot
    newrow = @youngestVisibleAncestor @cursor.row
    if newrow == null # not visible, need to reset cursor
      newrow = newroot
    @cursor.setRow newrow

  zoomOut: () ->
    if @viewRoot.id != @document.root.id
      parent = do @viewRoot.getParent
      @zoomInto parent

  zoomIn: () ->
    if @cursor.row.is @viewRoot
      return false
    newroot = @oldestVisibleAncestor @cursor.row
    if @zoomInto newroot
      return true
    return false

  zoomDown: () ->
    sib = @document.getSiblingAfter @viewRoot
    if sib == null
      @showMessage "No next sibling to zoom down to", {text_class: 'error'}
      return
    @zoomInto sib

  zoomUp: () ->
    sib = @document.getSiblingBefore @viewRoot
    if sib == null
      @showMessage "No previous sibling to zoom up to", {text_class: 'error'}
      return
    @zoomInto sib

  ##################
  # Text
  ##################

  curLine: () ->
    return @document.getLine @cursor.row.id

  curText: () ->
    return @document.getText @cursor.row

  curLineLength: () ->
    return @document.getLength @cursor.row

  addChars: (row, col, chars, options) ->
    @do new mutations.AddChars row, col, chars, options

  addCharsAtCursor: (chars, options) ->
    @addChars @cursor.row, @cursor.col, chars, options

  addCharsAfterCursor: (chars, options) ->
    col = @cursor.col
    if col < (@document.getLength @cursor.row)
      col += 1
    @addChars @cursor.row, col, chars, options

  delChars: (row, col, nchars, options = {}) ->
    n = @document.getLength row
    deleted = []
    if (n > 0) and (nchars > 0) and (col < n)
      mutation = new mutations.DelChars row, col, nchars, options
      @do mutation
      deleted = mutation.deletedChars
      if options.yank
        @register.saveChars deleted
    return deleted

  delCharsBeforeCursor: (nchars, options) ->
    nchars = Math.min(@cursor.col, nchars)
    return @delChars @cursor.row, (@cursor.col-nchars), nchars, options

  delCharsAfterCursor: (nchars, options) ->
    return @delChars @cursor.row, @cursor.col, nchars, options

  replaceCharsAfterCursor: (char, nchars, options) ->
    deleted = @delCharsAfterCursor nchars, {cursor: {pastEnd: true}}
    chars = []
    for obj in deleted
      newobj = _.clone obj
      newobj.char = char
      chars.push newobj
    @addCharsAtCursor chars, options

  clearRowAtCursor: () ->
    do @yankRowAtCursor
    @delChars @cursor.row, 0, (do @curLineLength)

  yankChars: (row, col, nchars) ->
    line = @document.getLine row.id
    if line.length > 0
      @register.saveChars line.slice(col, col + nchars)

  # options:
  #   - includeEnd says whether to also delete cursor2 location
  yankBetween: (cursor1, cursor2, options = {}) ->
    if not (cursor2.row.is cursor1.row)
      Logger.logger.warn "Not yet implemented"
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]

    offset = if options.includeEnd then 1 else 0
    @yankChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset)

  yankRowAtCursor: () ->
    serialized_row = @document.serializeRow @cursor.row
    @register.saveSerializedRows [serialized_row]

  # options:
  #   - includeEnd says whether to also delete cursor2 location
  deleteBetween: (cursor1, cursor2, options = {}) ->
    if not (cursor2.row.is cursor1.row)
      Logger.logger.warn "Not yet implemented"
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]
    offset = if options.includeEnd then 1 else 0
    @delChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset), options

  # toggling text properties
  # if new_value is null, should be inferred based on old values
  toggleProperty: (property, new_value, row, col, n) ->
    deleted = @delChars row, col, n, {setCursor: 'stay'}

    if new_value == null
      all_were_true = _.every deleted.map ((obj) -> return obj[property])
      new_value = not all_were_true

    chars = []
    for obj in deleted
      newobj = _.clone obj
      newobj[property] = new_value
      chars.push newobj
    @addChars row, col, chars, {setCursor: 'stay'}

  toggleRowsProperty: (property, rows) ->
    all_were_true = _.every rows.map ((row) =>
      _.every (@document.getLine row.id).map ((obj) -> return obj[property])
    )
    new_value = not all_were_true
    for row in rows
      @toggleProperty property, new_value, row, 0, (@document.getLength row)

  toggleRowProperty: (property, row = @cursor.row) ->
    @toggleProperty property, null, row, 0, (@document.getLength row)

  toggleRowPropertyBetween: (property, cursor1, cursor2, options) ->
    if not (cursor2.row.is cursor1.row)
      Logger.logger.warn "Not yet implemented"
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]

    offset = if options.includeEnd then 1 else 0
    @toggleProperty property, null, cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset)

  newLineBelow: (options = {}) ->
    options.setCursor = 'first'

    if @cursor.row.is @viewRoot
      if not (@document.hasChildren @cursor.row)
        if not @document.collapsed @cursor.row.id
          @toggleBlockCollapsed @cursor.row.id

      @addBlocks @cursor.row, 0, [''], options
    else if (not @document.collapsed @cursor.row.id) and @document.hasChildren @cursor.row
      @addBlocks @cursor.row, 0, [''], options
    else
      parent = do @cursor.row.getParent
      index = @document.indexOf @cursor.row
      @addBlocks parent, (index+1), [''], options

  newLineAbove: () ->
    parent = do @cursor.row.getParent
    index = @document.indexOf @cursor.row
    @addBlocks parent, index, [''], {setCursor: 'first'}

  # behavior of "enter", splitting a line
  # If enter is not at the end:
  #     insert a new node before with the first half of the content
  #     note that this will always preserve child-parent relationships
  # If enter is at the end:
  #     insert a new node after
  #     if the node has children, this is the new first child
  newLineAtCursor: () ->
    if @cursor.col == @document.getLength @cursor.row
      @newLineBelow {cursorOptions: {keepProperties: true}}
    else
      mutation = new mutations.DelChars @cursor.row, 0, @cursor.col
      @do mutation
      row = @cursor.row

      do @newLineAbove
      # cursor now is at inserted row, add the characters
      @addCharsAfterCursor mutation.deletedChars
      # restore cursor
      @cursor.set row, 0, {keepProperties: true}

  joinRows: (first, second, options = {}) ->
    for child in @document.getChildren second by -1
      # NOTE: if first is collapsed, should we uncollapse?
      @moveBlock child, first, 0

    line = @document.getLine second.id
    if line.length and options.delimiter
      if line[0].char != options.delimiter
        line = [{char: options.delimiter}].concat line
    @delBlock second, {noNew: true, noSave: true}

    newCol = @document.getLength first
    mutation = new mutations.AddChars first, newCol, line
    @do mutation

    @cursor.set first, newCol, options.cursor

  joinAtCursor: () ->
    row = @cursor.row
    sib = @nextVisible row
    if sib != null
      @joinRows row, sib, {cursor: {pastEnd: true}, delimiter: ' '}

  # implements proper "backspace" behavior
  deleteAtCursor: () ->
    if @cursor.col == 0
      row = @cursor.row
      sib = @prevVisible row
      if sib != null
        @joinRows sib, row, {cursor: {pastEnd: true}}
    else
      @delCharsBeforeCursor 1, {cursor: {pastEnd: true}}

  delBlock: (row, options) ->
    @delBlocks row.parent, (@document.indexOf row), 1, options

  delBlocks: (parent, index, nrows, options = {}) ->
    mutation = new mutations.DetachBlocks parent, index, nrows, options
    @do mutation
    unless options.noSave
      @register.saveClonedRows mutation.deleted
    if not (@isVisible @cursor.row)
      # view root got deleted
      do @zoomOut

  delBlocksAtCursor: (nrows, options = {}) ->
    parent = do @cursor.row.getParent
    index = @document.indexOf @cursor.row
    @delBlocks parent, index, nrows, options

  addBlocks: (parent, index = -1, serialized_rows, options = {}) ->
    mutation = new mutations.AddBlocks parent, index, serialized_rows, options
    @do mutation

  yankBlocks: (row, nrows) ->
    siblings = @document.getSiblingRange row, 0, (nrows-1)
    siblings = siblings.filter ((x) -> return x != null)
    serialized = siblings.map ((x) => return @document.serialize x)
    @register.saveSerializedRows serialized

  yankBlocksAtCursor: (nrows) ->
    @yankBlocks @cursor.row, nrows

  yankBlocksClone: (row, nrows) ->
    siblings = @document.getSiblingRange row, 0, (nrows-1)
    siblings = siblings.filter ((x) -> return x != null)
    @register.saveClonedRows (siblings.map (sibling) -> sibling.id)

  yankBlocksCloneAtCursor: (nrows) ->
    @yankBlocksClone @cursor.row, nrows

  attachBlocks: (parent, ids, index = -1, options = {}) ->
    mutation = new mutations.AttachBlocks parent, ids, index, options
    @do mutation

  moveBlock: (row, parent, index = -1, options = {}) ->
    [commonAncestor, rowAncestors, cursorAncestors] = @document.getCommonAncestor row, @cursor.row
    moved = @do new mutations.MoveBlock row, parent, index, options
    if moved
      # Move the cursor also, if it is in the moved block
      if commonAncestor.is row
        newCursorRow = @document.combineAncestry row, (x.id for x in cursorAncestors)
        @cursor._setRow newCursorRow
    return row

  indentBlocks: (row, numblocks = 1) ->
    if row.is @viewRoot
      @showMessage "Cannot indent view root", {text_class: 'error'}
      return
    newparent = @document.getSiblingBefore row
    unless newparent?
      @showMessage "Cannot indent without higher sibling", {text_class: 'error'}
      return null # cannot indent

    if @document.collapsed newparent.id
      @toggleBlockCollapsed newparent.id

    siblings = (@document.getSiblingRange row, 0, (numblocks-1)).filter ((sib) -> sib != null)
    for sib in siblings
      @moveBlock sib, newparent, -1
    return newparent

  unindentBlocks: (row, numblocks = 1, options = {}) ->
    if row.is @viewRoot
      @showMessage "Cannot unindent view root", {text_class: 'error'}
      return
    parent = do row.getParent
    if parent.id == @viewRoot.id
      @showMessage "Cannot unindent past root", {text_class: 'error'}
      return null

    siblings = (@document.getSiblingRange row, 0, (numblocks-1)).filter ((sib) -> sib != null)

    newparent = do parent.getParent
    pp_i = @document.indexOf parent

    for sib in siblings
      pp_i += 1
      @moveBlock sib, newparent, pp_i
    return newparent

  indent: (row = @cursor.row) ->
    if row.is @viewRoot
      @showMessage "Cannot indent view root", {text_class: 'error'}
      return
    if @document.collapsed row.id
      return @indentBlocks row

    sib = @document.getSiblingBefore row

    newparent = @indentBlocks row
    unless newparent?
      return
    for child in (@document.getChildren row).slice()
      @moveBlock child, sib, -1

  unindent: (row = @cursor.row) ->
    if row.is @viewRoot
      @showMessage "Cannot unindent view root", {text_class: 'error'}
      return
    if @document.collapsed row.id
      return @unindentBlocks row

    if @document.hasChildren row
      @showMessage "Cannot unindent line with children", {text_class: 'error'}
      return

    parent = do row.getParent
    p_i = @document.indexOf row

    newparent = @unindentBlocks row
    unless newparent?
      return

    p_children = @document.getChildren parent
    for child in p_children.slice(p_i)
      @moveBlock child, row, -1

  swapDown: (row = @cursor.row) ->
    next = @nextVisible (@lastVisible row)
    unless next?
      return

    if (@document.hasChildren next) and (not @document.collapsed next.id)
      # make it the first child
      @moveBlock row, next, 0
    else
      # make it the next sibling
      parent = do next.getParent
      p_i = @document.indexOf next
      @moveBlock row, parent, (p_i+1)

  swapUp: (row = @cursor.row) ->
    prev = @prevVisible row
    unless prev?
      return

    # make it the previous sibling
    parent = do prev.getParent
    p_i = @document.indexOf prev
    @moveBlock row, parent, p_i

  toggleCurBlockCollapsed: () ->
    @toggleBlockCollapsed @cursor.row.id

  toggleBlockCollapsed: (row) ->
    @do new mutations.ToggleBlock row

  pasteBefore: (options = {}) ->
    options.before = true
    @register.paste options

  pasteAfter: (options = {}) ->
    @register.paste options

  # given an anchor and cursor, figures out the right blocks to be deleting
  # returns a parent, minindex, and maxindex
  getVisualLineSelections: () ->
    [common, ancestors1, ancestors2] = @document.getCommonAncestor @cursor.row, @anchor.row
    if ancestors1.length == 0
      # anchor is underneath cursor
      parent = do common.getParent
      index = @document.indexOf @cursor.row
      return [parent, index, index]
    else if ancestors2.length == 0
      # cursor is underneath anchor
      parent = do common.getParent
      index = @document.indexOf @anchor.row
      return [parent, index, index]
    else
      index1 = @document.indexOf (ancestors1[0] ? @cursor.row)
      index2 = @document.indexOf (ancestors2[0] ? @anchor.row)
      if index2 < index1
        [index1, index2] = [index2, index1]
      return [common, index1, index2]

  ###################
  # scrolling
  ###################

  scroll: (npages) ->
    @emit 'scroll', npages
    # TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
    line_height = $('.node-text').height() or 21
    errors.assert (line_height > 0)
    page_height = do $(document).height
    height = npages * page_height

    numlines = Math.round(height / line_height)
    numlines = Math.max(Math.min(numlines, 1000), -1000) # guard against craziness

    if numlines > 0
      for i in [1..numlines]
        do @cursor.down
    else
      for i in [-1..numlines]
        do @cursor.up

    @scrollMain (line_height * numlines)

  scrollMain: (amount) ->
    # # animate.  seems to not actually be great though
    # @mainDiv.stop().animate({
    #     scrollTop: @mainDiv[0].scrollTop + amount
    #  }, 50)
    @mainDiv.scrollTop(@mainDiv.scrollTop() + amount)

  scrollIntoView: (el) ->
    elemTop = el.getBoundingClientRect().top
    elemBottom = el.getBoundingClientRect().bottom

    margin = 50
    top_margin = margin
    bottom_margin = margin + $('#bottom-bar').height()

    if elemTop < top_margin
      # scroll up
      @scrollMain (elemTop - top_margin)
    else if elemBottom > window.innerHeight - bottom_margin
      # scroll down
      @scrollMain (elemBottom - window.innerHeight + bottom_margin)

  getVisibleRows: () ->
    rows = []
    for bullet in $.makeArray($('.bullet'))
      if not (utils.isScrolledIntoView $(bullet), @mainDiv)
        continue
      if $(bullet).hasClass 'fa-clone'
        continue
      # NOTE: can't use $(x).data
      # http://stackoverflow.com/questions/25876274/jquery-data-not-working
      ancestry = $(bullet).attr('data-ancestry')
      if not ancestry # as far as i know, this only happens because of menu mode
        continue
      row = Path.loadFromAncestry JSON.parse ancestry
      rows.push row
    return rows

# exports
module.exports = Session
