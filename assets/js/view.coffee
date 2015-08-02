# imports
if module?
  _ = require('underscore')

  actions = require('./actions.coffee')
  constants = require('./constants.coffee')
  Cursor = require('./cursor.coffee')
  Data = require('./data.coffee')
  dataStore = require('./datastore.coffee')
  Register = require('./register.coffee')
  Logger = require('./logger.coffee')

# a View consists of Data and a cursor
# it also renders

renderLine = (lineData, options = {}) ->
  options.cursors ?= {}
  options.highlights ?= {}
  options.marks ?= {}

  results = []

  if options.mark
    results.push virtualDom.h 'span', {
      className: 'mark'
    }, options.mark


  # ideally this takes up space but is unselectable (uncopyable)
  cursorChar = ' '

  line = []

  # add cursor if at end
  if lineData.length of options.cursors
    lineData.push {char: cursorChar}

  if lineData.length == 0
    # if absolutely nothing, we want a character that takes up height,
    # but doesn't copy as anything
    results.push virtualDom.h 'span', {innerHTML: '&zwnj;'}
    return results

  for obj, i in lineData
    info = {
      column: i
    }
    renderOptions = {
      classes: []
      type: 'span'
    }

    # make sure .bold, .italic, .strikethrough, .underline correspond to the text properties
    for property in constants.text_properties
      if obj[property]
        renderOptions.classes.push property

    x = obj.char

    if obj.char == '\n'
      # tricky logic for rendering new lines within a bullet
      # (copies correctly, works when cursor is on the newline itself)
      x = ''
      info.break = true
      if i of options.cursors
        x = cursorChar + x

    if i of options.cursors
      renderOptions.classes.push 'cursor'
    if i of options.highlights
      renderOptions.classes.push 'highlight'

    info.char = x
    info.renderOptions = renderOptions

    line.push info

  # collect set of words, { word: word, start: start, end: end }
  words = []
  word = ''
  word_start = 0

  isWhitespace = (char) ->
    return char == '\n' or char == ' '
  isPunctuation = (char) ->
    return char == '.' or char == ',' or char == '!' or char == '?'

  for obj, i in lineData.concat [{char: ' '}] # to make end condition easier
    # TODO  or (isPunctuation obj.char)
    # problem is URLs have dots in them...
    if (isWhitespace obj.char)
      if i != word_start
        words.push {
          word: word
          start: word_start
          end: i - 1
        }
      word_start = i + 1
      word = ''
    else
      word += obj.char

  # gather words that are urls
  urlRegex = /^https?:\/\/[^\s]+\.[^\s]+$/
  url_words = words.filter (w) ->
    return urlRegex.test w.word

  for url_word in url_words
    for i in [url_word.start..url_word.end]
      line[i].renderOptions.type = 'a'
      line[i].renderOptions.classes.push 'link'
      line[i].renderOptions.href = url_word.word

  if options.onclickmark?
    # gather words that are marks
    for word in words
      if word.word[0] == '@'
        mark = word.word[1..]
        if mark of options.marks
          row = options.marks[mark]
          for i in [word.start..word.end]
            line[i].renderOptions.type = 'a'
            line[i].renderOptions.classes.push 'link'
            line[i].renderOptions.onclick = options.onclickmark.bind @, row


  renderSpec = []
  # Normally, we collect things of the same type and render them in one div
  # If there are column-specific handlers, however, we must break up the div to handle
  # separate click events
  if options.charclick
    for x in line
      x.renderOptions.text = x.char
      if not x.renderOptions.onclick
        x.renderOptions.onclick = options.charclick.bind @, x.column
      renderSpec.push x.renderOptions
      if x.break
        renderSpec.push {type: 'div'}
  else
    acc = ''
    renderOptions = {}

    flush = () ->
      if acc.length
        renderOptions.text = acc
        renderOptions.onmouseover = options.linemouseover
        renderSpec.push renderOptions
      acc = ''
      renderOptions = {}

    # collect line into groups to render
    for x in line
      if _.isEqual x.renderOptions, renderOptions
        acc += x.char
      else
        do flush
        acc = x.char
        renderOptions = x.renderOptions

      if x.break
        do flush
        renderSpec.push {type: 'div'}
    do flush

  for spec in renderSpec
    divoptions = {}
    if spec.classes
      divoptions.className = (spec.classes.join ' ')
    if spec.href
      divoptions.href = spec.href
    if spec.onclick
      divoptions.onclick = spec.onclick
    if spec.onmouseover
      divoptions.onmouseover = spec.onmouseover

    results.push virtualDom.h spec.type, divoptions, spec.text

  return results

(() ->
  MODES = constants.MODES

  class View
    containerDivID = (id) ->
      return 'node-' + id

    rowDivID = (id) ->
      return 'node-' + id + '-row'

    childrenDivID = (id) ->
      return 'node-' + id + '-children'

    constructor: (data, options = {}) ->
      @data = data

      @bindings = options.bindings

      @mainDiv = options.mainDiv
      @settingsDiv = options.settingsDiv
      @keybindingsDiv = options.keybindingsDiv
      @messageDiv = options.messageDiv
      @menuDiv = options.menuDiv
      @modeDiv = options.modeDiv

      row = (@data.getChildren @data.viewRoot)[0]
      @cursor = new Cursor @data, row, 0
      @register = new Register @

      @actions = [] # full action history
      @history = [{
        index: 0
      }]
      @historyIndex = 0 # index into indices

      @jumpHistory = [{
        viewRoot: @data.viewRoot
        cursor_before: do @cursor.clone
      }]
      @jumpIndex = 0 # index into jump history

      if @mainDiv?
        @vtree = do @virtualRender
        @vnode = virtualDom.create @vtree
        @mainDiv.append @vnode

      if @settingsDiv?
        @settings = new Settings @data.store, {mainDiv: @settingsDiv, keybindingsDiv: @keybindingsDiv}
        do @settings.loadRenderSettings

      @mode = null
      @setMode MODES.NORMAL

      return @


    #################
    # modes related
    #################

    setMode: (mode) ->
      @mode = mode
      if @modeDiv
        for k, v of MODES
          if v == mode
            @modeDiv.text k
            break

      if mode == MODES.MARK
        # initialize marks stuff
        data = new Data (new dataStore.InMemory)
        data.load {
          text: ''
          children: ['']
        }
        @markview = new View data
        @markrow = @cursor.row

      if @menuDiv
        @menuDiv.toggleClass 'hidden', (mode != MODES.MENU)
      if @keybindingsDiv
        @keybindingsDiv.toggleClass 'hidden', (mode == MODES.MENU)
      if @mainDiv
        @mainDiv.toggleClass 'hidden', (mode == MODES.MENU)
      do @buildBindingsDiv

    buildBindingsDiv: () ->
      if not @keybindingsDiv
        return
      if not (@settings.getSetting 'showKeyBindings')
        return

      modeKeymap = @bindings.maps[@mode] || {}

      table = $('<table>')

      buildTableContents = (definitions, onto) =>
        for k,v of definitions
          if k == 'MOTION'
            keys = ['<MOTION>']
          else
            keys = modeKeymap[k]
            if not keys
              continue

          if keys.length == 0
            continue

          row = $('<tr>')

          # row.append $('<td>').text keys[0]
          row.append $('<td>').text keys.join(' OR ')

          display_cell = $('<td>').css('width', '100%').text v.display
          if v.bindings
            buildTableContents v.bindings, display_cell
          row.append display_cell

          onto.append row

      buildTableContents @bindings.definitions, table
      @keybindingsDiv.empty().append(table)


    #################
    # show message
    #################

    showMessage: (message, options = {}) ->
      options.time ?= 5000
      if @messageDiv
        clearTimeout @messageDivTimeout
        @messageDiv.text(message)
        @messageDivTimeout = setTimeout (() =>
          @messageDiv.text('')
        ), options.time

    ##########
    # export
    ##########

    export: (filename, mimetype) ->
      filename ||= @settings?.getSetting?('export_filename') || 'vimflowy.json'
      if not mimetype? # Infer mimetype from file extension
          mimetype = @mimetypeLookup filename
      content = @exportContent mimetype
      @saveFile filename, mimetype, content

    exportContent: (mimetype) ->
      jsonContent = do @data.serialize
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

    # ACTIONS

    save: () ->
      if @historyIndex != @history.length - 1
          # haven't acted, otherwise would've sliced
          return
      if @history[@historyIndex].index == @actions.length
          # haven't acted, otherwise there would be more actions
          return

      state = @history[@historyIndex]
      state.after = {
        cursor: do @cursor.clone
        viewRoot: @data.viewRoot
      }

      @historyIndex += 1
      @history.push {
        index: @actions.length
      }

    restoreViewState: (state) ->
      @cursor.from state.cursor
      if @mode != MODES.INSERT
        do @cursor.backIfNeeded
      @_changeView state.viewRoot

    undo: () ->
      if @historyIndex > 0
        oldState = @history[@historyIndex]
        @historyIndex -= 1
        newState = @history[@historyIndex]

        Logger.logger.debug "UNDOING ("
        for i in [(oldState.index-1)...(newState.index-1)]
            action = @actions[i]
            Logger.logger.debug "  Undoing action #{action.constructor.name}(#{action.str()})"
            action.rewind @
        Logger.logger.debug ") END UNDO"
        @restoreViewState newState.before

    redo: () ->
      if @historyIndex < @history.length - 1
        oldState = @history[@historyIndex]
        @historyIndex += 1
        newState = @history[@historyIndex]

        Logger.logger.debug "REDOING ("
        for i in [oldState.index...newState.index]
            action = @actions[i]
            Logger.logger.debug "  Redoing action #{action.constructor.name}(#{action.str()})"
            action.reapply @
        Logger.logger.debug ") END REDO"
        @restoreViewState oldState.after

    act: (action) ->
      if @historyIndex != @history.length - 1
          @history = @history.slice 0, (@historyIndex + 1)
          @actions = @actions.slice 0, @history[@historyIndex].index

      state = @history[@historyIndex]
      if @actions.length == state.index
        state.before = {
          cursor: do @cursor.clone
          viewRoot: @data.viewRoot
        }

      Logger.logger.debug "Applying action #{action.constructor.name}(#{action.str()})"
      action.apply @
      @actions.push action

    curLine: () ->
      return @data.getLine @cursor.row

    curText: () ->
      return @data.getText @cursor.row

    curLineLength: () ->
      return @data.getLength @cursor.row

    addToJumpHistory: (jump_fn) ->
      jump = @jumpHistory[@jumpIndex]
      jump.cursor_after = do @cursor.clone

      @jumpHistory = @jumpHistory.slice 0, (@jumpIndex+1)

      do jump_fn

      @jumpHistory.push {
        viewRoot: @data.viewRoot
        cursor_before: do @cursor.clone
      }
      @jumpIndex += 1

    # try going to jump, return true if succeeds
    tryJump: (jump) ->
      if jump.viewRoot == @data.viewRoot
        return false # not moving, don't jump

      if not @data.isAttached jump.viewRoot
        return false # invalid location

      children = @data.getChildren jump.viewRoot
      if not children.length
        return false # can't root, don't jump

      @data.changeViewRoot jump.viewRoot
      @cursor.setRow children[0]

      if @data.isAttached jump.cursor_after.row
        # if the row is attached and under the view root, switch to it
        cursor_row = @data.youngestVisibleAncestor jump.cursor_after.row
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
    _changeView: (row) ->
      if row == @data.viewRoot
        return true # not moving, do nothing
      if @data.hasChildren row
        @addToJumpHistory () =>
          @data.changeViewRoot row
        return true
      return false

    # try to root into newroot, updating the cursor
    reroot: (newroot = @data.root) ->
      if @_changeView newroot
        newrow = @data.youngestVisibleAncestor @cursor.row
        if newrow == null # not visible, need to reset cursor
          newrow = (@data.getChildren newroot)[0]
        @cursor.setRow newrow
        return true
      return false

    # try rerooting to row, otherwise reroot to its parent
    rootInto: (row = @cursor.row) ->
      if @reroot row
        return true
      parent = @data.getParent row
      if @reroot parent
        @cursor.setRow row
        return true
      throw 'Failed to root into'

    rootUp: () ->
      if @data.viewRoot != @data.root
        parent = @data.getParent @data.viewRoot
        @reroot parent

    rootDown: () ->
      newroot = @data.oldestVisibleAncestor @cursor.row
      if @reroot newroot
        return true
      return false

    # go to the mark under the cursor, if it exists
    goMark: () ->
      word = @data.getWord @cursor.row, @cursor.col
      if word.length < 1 or word[0] != '@'
        return false
      mark = word[1..]
      allMarks = do @data.getAllMarks
      if mark of allMarks
        row = allMarks[mark]
        @rootInto row
        return true
      else
        return false

    addChars: (row, col, chars, options) ->
      @act new actions.AddChars row, col, chars, options

    addCharsAtCursor: (chars, options) ->
      @addChars @cursor.row, @cursor.col, chars, options

    addCharsAfterCursor: (chars, options) ->
      col = @cursor.col
      if col < (@data.getLength @cursor.row)
        col += 1
      @addChars @cursor.row, col, chars, options

    delChars: (row, col, nchars, options = {}) ->
      n = @data.getLength row
      deleted = []
      if (n > 0) and (nchars > 0) and (col < n)
        delAction = new actions.DelChars row, col, nchars, options
        @act delAction
        deleted = delAction.deletedChars
        if options.yank
          @register.saveChars deleted
      return deleted

    delCharsBeforeCursor: (nchars, options) ->
      nchars = Math.min(@cursor.col, nchars)
      return @delChars @cursor.row, (@cursor.col-nchars), nchars, options

    delCharsAfterCursor: (nchars, options) ->
      return @delChars @cursor.row, @cursor.col, nchars, options

    # spliceCharsAfterCursor: (nchars, chars, options) ->
    #   @delCharsAfterCursor nchars, {cursor: {pastEnd: true}}
    #   @addCharsAtCursor chars, options

    replaceCharsAfterCursor: (char, nchars, options) ->
      deleted = @delCharsAfterCursor nchars, {cursor: {pastEnd: true}}
      chars = []
      for obj in deleted
        newobj = _.clone obj
        newobj.char = char
        chars.push newobj
      @addCharsAtCursor chars, options

    yankChars: (row, col, nchars) ->
      line = @data.getLine row
      if line.length > 0
        @register.saveChars line.slice(col, col + nchars)

    # options:
    #   - includeEnd says whether to also delete cursor2 location
    yankBetween: (cursor1, cursor2, options = {}) ->
      if cursor2.row != cursor1.row
        Logger.logger.warn "Not yet implemented"
        return

      if cursor2.col < cursor1.col
        [cursor1, cursor2] = [cursor2, cursor1]

      offset = if options.includeEnd then 1 else 0
      @yankChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset)

    # options:
    #   - includeEnd says whether to also delete cursor2 location
    deleteBetween: (cursor1, cursor2, options = {}) ->
      if cursor2.row != cursor1.row
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
        all_were_true = _.all deleted.map ((obj) => return obj[property])
        new_value = not all_were_true

      chars = []
      for obj in deleted
        newobj = _.clone obj
        newobj[property] = new_value
        chars.push newobj
      @addChars row, col, chars, {setCursor: 'stay'}

    toggleRowsProperty: (property, rows) ->
      all_were_true = _.all rows.map ((row) =>
        _.all (@data.getLine row).map ((obj) => return obj[property])
      )
      new_value = not all_were_true
      for row in rows
        @toggleProperty property, new_value, row, 0, (@data.getLength row)

    toggleRowProperty: (property, row = @cursor.row) ->
      @toggleProperty property, null, row, 0, (@data.getLength row)

    toggleRowPropertyBetween: (property, cursor1, cursor2, options) ->
      if cursor2.row != cursor1.row
        Logger.logger.warn "Not yet implemented"
        return

      if cursor2.col < cursor1.col
        [cursor1, cursor2] = [cursor2, cursor1]

      offset = if options.includeEnd then 1 else 0
      @toggleProperty property, null, cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset)

    newLineBelow: () ->
      children = @data.getChildren @cursor.row
      if (not @data.collapsed @cursor.row) and children.length > 0
        @act new actions.InsertRowSibling children[0], {before: true}
      else
        @act new actions.InsertRowSibling @cursor.row, {after: true}

    newLineAbove: () ->
      @act new actions.InsertRowSibling @cursor.row, {before: true}

    newLineAtCursor: () ->
      delAction = new actions.DelChars @cursor.row, 0, @cursor.col
      @act delAction
      row = @cursor.row
      sibling = @act new actions.InsertRowSibling @cursor.row, {before: true}
      @addCharsAfterCursor delAction.deletedChars
      @cursor.set row, 0, {keepProperties: true}

    joinRows: (first, second, options = {}) ->
      for child in @data.getChildren second by -1
        # NOTE: if first is collapsed, should we uncollapse?
        @moveBlock child, first, 0

      line = @data.getLine second
      if options.delimiter
        if line[0].char != options.delimiter
          line = [{char: options.delimiter}].concat line
      @detachBlock second

      newCol = @data.getLength first
      action = new actions.AddChars first, newCol, line
      @act action

      @cursor.set first, newCol, options.cursor

    joinAtCursor: () ->
      row = @cursor.row
      sib = @data.nextVisible row
      if sib != null
        @joinRows row, sib, {cursor: {pastEnd: true}, delimiter: ' '}

    # implements proper "backspace" behavior
    deleteAtCursor: () ->
      if @cursor.col == 0
        row = @cursor.row
        sib = @data.prevVisible row
        if sib != null
          @joinRows sib, row, {cursor: {pastEnd: true}}
      else
        @delCharsBeforeCursor 1, {cursor: {pastEnd: true}}

    delBlocks: (nrows, options = {}) ->
      action = new actions.DeleteBlocks @cursor.row, nrows, options
      @act action
      @register.saveRows action.deleted_rows

    addBlocks: (serialized_rows, parent, index = -1, options = {}) ->
      action = new actions.AddBlocks serialized_rows, parent, index, options
      @act action

    yankBlocks: (nrows) ->
      siblings = @data.getSiblingRange @cursor.row, 0, (nrows-1)
      siblings = siblings.filter ((x) -> return x != null)
      serialized = siblings.map ((x) => return @data.serialize x)
      @register.saveSerializedRows serialized

    detachBlock: (row, options = {}) ->
      action = new actions.DetachBlock row, options
      @act action
      return action

    attachBlocks: (rows, parent, index, options = {}) ->
      for row in rows
        @attachBlock row, parent, index, options
        index += 1

    attachBlock: (row, parent, index = -1, options = {}) ->
      @act new actions.AttachBlock row, parent, index, options

    moveBlock: (row, parent, index = -1, options = {}) ->
      @detachBlock row, options
      @attachBlock row, parent, index, options

    indentBlocks: (id, numblocks = 1) ->
      newparent = @data.getSiblingBefore id
      if newparent == null
        return null # cannot indent

      if @data.collapsed newparent
        @toggleBlock newparent

      siblings = @data.getSiblingRange id, 0, (numblocks-1)
      for sib in siblings
        @moveBlock sib, newparent, -1
      return newparent

    unindentBlocks: (id, numblocks = 1, options = {}) ->
      parent = @data.getParent id
      if parent == @data.viewRoot
        return null

      siblings = @data.getSiblingRange id, 0, (numblocks-1)

      newparent = @data.getParent parent
      pp_i = @data.indexOf parent

      for sib in siblings
        pp_i += 1
        @moveBlock sib, newparent, pp_i
      return newparent

    indent: (id = @cursor.row) ->
      sib = @data.getSiblingBefore id

      newparent = @indentBlocks id
      if newparent == null
        return
      for child in (@data.getChildren id).slice()
        @moveBlock child, sib, -1

    unindent: (id = @cursor.row) ->
      if @data.hasChildren id
        return

      parent = @data.getParent id
      p_i = @data.indexOf id

      newparent = @unindentBlocks id
      if newparent == null
        return

      p_children = @data.getChildren parent
      for child in p_children.slice(p_i)
        @moveBlock child, id, -1

    swapDown: (row = @cursor.row) ->
      next = @data.nextVisible (@data.lastVisible row)
      if next == null
        return

      @detachBlock row
      if (@data.hasChildren next) and (not @data.collapsed next)
        # make it the first child
        @attachBlock row, next, 0
      else
        # make it the next sibling
        parent = @data.getParent next
        p_i = @data.indexOf next
        @attachBlock row, parent, (p_i+1)

    swapUp: (row = @cursor.row) ->
      prev = @data.prevVisible row
      if prev == null
        return

      @detachBlock row
      # make it the previous sibling
      parent = @data.getParent prev
      p_i = @data.indexOf prev
      @attachBlock row, parent, p_i

    toggleCurBlock: () ->
      @toggleBlock @cursor.row

    toggleBlock: (row) ->
      @act new actions.ToggleBlock row

    pasteBefore: (options = {}) ->
      options.before = true
      @register.paste options

    pasteAfter: (options = {}) ->
      @register.paste options

    find: (chars, nresults = 10) ->
      results = @data.find chars, nresults
      return results

    setMark: (row, mark) ->
      allMarks = do @data.store.getAllMarks
      if not (mark of allMarks)
        @act new actions.SetMark row, mark
        return true
      else
        @showMessage "Mark '#{mark}' is already taken"
        return false

    scrollPages: (npages) ->
      # TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
      line_height = do $('.node-text').height
      page_height = do $(document).height
      height = npages * page_height

      numlines = Math.round(height / line_height)
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

    # RENDERING

    render: (options = {}) ->
      t = Date.now()
      vtree = @virtualRender options
      patches = virtualDom.diff @vtree, vtree
      @vnode = virtualDom.patch @vnode, patches
      @vtree = vtree
      Logger.logger.debug 'Rendering: ', !!options.handle_clicks, (Date.now()-t)

      cursorDiv = $('.cursor', @mainDiv)[0]
      if cursorDiv
        @scrollIntoView cursorDiv

      return

    virtualRender: (options = {}) ->
      crumbs = []
      row = @data.viewRoot
      while row != @data.root
        crumbs.push row
        row = @data.getParent row

      makeCrumb = (row, text) =>
        m_options = {}
        if @mode == MODES.NORMAL
          m_options.onclick = () =>
            @reroot row
            do @save
            do @render
        return virtualDom.h 'span', { className: 'crumb' }, [
                 virtualDom.h 'a', m_options, [ text ]
               ]

      crumbNodes = []
      crumbNodes.push(makeCrumb @data.root, (virtualDom.h 'icon', {className: 'fa fa-home'}))
      for row in crumbs by -1
        text = (@data.getText row).join('')
        crumbNodes.push(makeCrumb row, text)

      breadcrumbsNode = virtualDom.h 'div', {
        id: 'breadcrumbs'
      }, crumbNodes

      options.ignoreCollapse = true # since we're the root, even if we're collapsed, we should render
      contentsChildren = @virtualRenderTree @data.viewRoot, options

      contentsNode = virtualDom.h 'div', {
        id: 'treecontents'
      }, contentsChildren

      return virtualDom.h 'div', {
      }, [breadcrumbsNode, contentsNode]

    virtualRenderTree: (parentid, options = {}) ->
      if (not options.ignoreCollapse) and (@data.collapsed parentid)
        return

      childrenNodes = []

      highlighted = {}
      if @lineSelect
        if parentid == @data.getParent @cursor.row
          index1 = @data.indexOf @cursor.row
          index2 = @data.indexOf @anchor.row
          if index2 < index1
            [index1, index2] = [index2, index1]
          for i in [index1..index2]
            highlighted[i] = true

      for i, id of @data.getChildren parentid

        icon = 'fa-circle'
        if @data.hasChildren id
          icon = if @data.collapsed id then 'fa-plus-circle' else 'fa-minus-circle'

        bulletOpts = {
          className: 'fa ' + icon + ' bullet'
        }
        if @data.hasChildren id
          bulletOpts.style = {cursor: 'pointer'}
          bulletOpts.onclick = ((id) =>
            @toggleBlock id
            do @save
            do @render
          ).bind(@, id)

        bullet = virtualDom.h 'i', bulletOpts

        elLine = virtualDom.h 'div', {
          id: rowDivID id
          className: 'node-text'
        }, (@virtualRenderLine id, options)

        options.ignoreCollapse = false
        children = virtualDom.h 'div', {
          id: childrenDivID id
          className: 'node-children'
        }, (@virtualRenderTree id, options)

        className = 'node'
        if i of highlighted
          className += ' highlight'

        childNode = virtualDom.h 'div', {
          id: containerDivID id
          className: className
        }, [bullet, elLine, children]

        childrenNodes.push childNode
      return childrenNodes

    virtualRenderLine: (row, options = {}) ->

      lineData = @data.getLine row
      cursors = {}
      highlights = {}

      marking = @markrow == row

      if row == @cursor.row and not marking
        cursors[@cursor.col] = true

        if @anchor and not @lineSelect
          if row == @anchor.row
            for i in [@cursor.col..@anchor.col]
              highlights[i] = true
          else
            Logger.logger.warn "Multiline not yet implemented"

      results = []

      mark = null
      if marking
          markresults = @markview.virtualRenderLine @markview.cursor.row
          results.push virtualDom.h 'span', {
            className: 'mark active'
          }, markresults
      else
          mark = @data.getMark row

      lineoptions = {
        cursors: cursors
        highlights: highlights
        marks: (do @data.getAllMarks)
        mark: mark
      }

      if options.handle_clicks
        if @mode == MODES.NORMAL or @mode == MODES.INSERT
          lineoptions.charclick = (column) =>
            @cursor.set row, column
            # assume they might click again
            @render {handle_clicks: true}
      else
        lineoptions.linemouseover = () =>
          @render {handle_clicks: true}

      if @mode == MODES.NORMAL
        lineoptions.onclickmark = (row) =>
          @rootInto row
          do @save
          do @render
      lineContents = renderLine lineData, lineoptions
      [].push.apply results, lineContents
      return results

  # exports
  module?.exports = View
  window?.View = View
)()
