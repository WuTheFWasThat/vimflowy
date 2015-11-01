if module?
  global.constants = require('./constants.coffee')

###
keyDefinitions defines the set of possible commands.
Each command has a name, which the keyDefinitions dictionary maps to a definition,
which describes what the command should do in various modes.

Each definition has the following required fields:
    description:
        a string used for description in keybindings help screen
The definition should have functions for each mode that it supports
The functions will be passed contexts depending on each mode
  TODO: document these
  view:
  keyStream:
  repeat:
It may also have, bindings:
    another (recursive) set of key definitions, i.e. a dictionary from command names to definitions

NOTE: there is a special command called 'MOTION', which is used in the bindings dictionaries
    much like if the motion boolean is true, this command always takes an extra cursor argument.
    TODO: this is a hack, and should be done more properly

For more info/context, see keyBindings.coffee
###

((exports) ->
  MODES = constants.MODES

  visual_line_mode_delete_fn = () ->
    return () ->
      @view.delBlocks @parent, @row_start_i, @num_rows, {addNew: false}
      @view.setMode MODES.NORMAL
      do @keyStream.save

  visual_mode_delete_fn = () ->
    return () ->
      options = {includeEnd: true, yank: true}
      @view.deleteBetween @view.cursor, @view.anchor, options
      @view.setMode MODES.NORMAL
      do @keyStream.save

  visual_line_indent = () ->
    return () ->
      @view.indentBlocks @row_start, @num_rows
      @view.setMode MODES.NORMAL
      do @keyStream.save

  visual_line_unindent = () ->
    return () ->
      @view.unindentBlocks @row_start, @num_rows
      @view.setMode MODES.NORMAL
      do @keyStream.save

  # MOTIONS
  # should have a fn, returns a motion fn (or null)
  # the motion itself should take a cursor, and and options dictionary
  # (it should presumably move the cursor, somehow)
  # options include:
  #     pastEnd: whether to allow going past the end of the line
  #     pastEndWord: whether we consider the end of a word to be after the last letter

  motionDefinitions = {}

  registerSubmotion = (
    mainDefinition,
    name,
    description,
    definition
  ) ->
    mainDefinition[name] = {
      name: name
      description: description
      definition: definition
    }

  registerMotion = registerSubmotion.bind @, motionDefinitions

  registerMotion 'LEFT', 'Move cursor left', () ->
    return (cursor, options) ->
      cursor.left options

  registerMotion 'RIGHT', 'Move cursor right', () ->
    return (cursor, options) ->
      cursor.right options

  registerMotion 'UP', 'Move cursor up', () ->
    return (cursor, options) ->
      cursor.up options

  registerMotion 'DOWN', 'Move cursor down', () ->
    return (cursor, options) ->
      cursor.down options

  registerMotion 'HOME', 'Move cursor to beginning of line', () ->
    return (cursor, options) ->
      cursor.home options

  registerMotion 'END', 'Move cursor to end of line', () ->
    return (cursor, options) ->
      cursor.end options

  registerMotion 'BEGINNING_WORD', 'Move cursor to the first word-beginning before it', () ->
    return (cursor, options) ->
      cursor.beginningWord {cursor: options}

  registerMotion 'END_WORD', 'Move cursor to the first word-ending after it', () ->
    return (cursor, options) ->
      cursor.endWord {cursor: options}

  registerMotion 'NEXT_WORD', 'Move cursor to the beginning of the next word', () ->
    return (cursor, options) ->
      cursor.nextWord {cursor: options}

  registerMotion 'BEGINNING_WWORD', 'Move cursor to the first Word-beginning before it', () ->
    return (cursor, options) ->
      cursor.beginningWord {cursor: options, whitespaceWord: true}

  registerMotion 'END_WWORD', 'Move cursor to the first Word-ending after it', () ->
    return (cursor, options) ->
      cursor.endWord {cursor: options, whitespaceWord: true}

  registerMotion 'NEXT_WWORD', 'Move cursor to the beginning of the next Word', () ->
    return (cursor, options) ->
      cursor.nextWord {cursor: options, whitespaceWord: true}

  registerMotion 'FIND_NEXT_CHAR', 'Move cursor to next occurrence of character in line', () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findNextChar key, {cursor: options}

  registerMotion 'FIND_PREV_CHAR', 'Move cursor to previous occurrence of character in line', () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findPrevChar key, {cursor: options}

  registerMotion 'TO_NEXT_CHAR', 'Move cursor to just before next occurrence of character in line', () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findNextChar key, {cursor: options, beforeFound: true}

  registerMotion 'TO_PREV_CHAR', 'Move cursor to just after previous occurrence of character in line', () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findPrevChar key, {cursor: options, beforeFound: true}

  registerMotion 'NEXT_SIBLING', 'Move cursor to the next sibling of the current line', () ->
    return (cursor, options) ->
      cursor.nextSibling options

  registerMotion 'PREV_SIBLING', 'Move cursor to the previous sibling of the current line', () ->
    return (cursor, options) ->
      cursor.prevSibling options


  registerMotion 'GO_END', 'Go to end of visible document', () ->
    return (cursor, options) ->
      cursor.visibleEnd options

  registerMotion 'EASY_MOTION', 'Jump to a visible row (based on EasyMotion)', () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait

      ids = do @view.getVisibleRows
      ids = ids.filter (row) => return (row.id != @view.cursor.row.id)
      keys = [
        'z', 'x', 'c', 'v',
        'q', 'w', 'e', 'r', 't',
        'a', 's', 'd', 'f',
        'g', 'h', 'j', 'k', 'l',
        'y', 'u', 'i', 'o', 'p',
        'b', 'n', 'm',
      ]

      if keys.length > ids.length
        start = (keys.length - ids.length) / 2
        keys = keys.slice(start, start + ids.length)
      else
        start = (ids.length - keys.length) / 2
        ids = ids.slice(start, start + ids.length)

      mappings = {
        key_to_id: {}
        id_to_key: {}
      }
      for [id, key] in _.zip(ids, keys)
        mappings.key_to_id[key] = id
        mappings.id_to_key[id] = key
      @view.easy_motion_mappings = mappings

      return null
    else
      return (cursor, options) ->
        if key of @view.easy_motion_mappings.key_to_id
          id = @view.easy_motion_mappings.key_to_id[key]
          row = @view.data.canonicalInstance id
          cursor.set row, 0
        @view.easy_motion_mappings = null

  go_definition = {} # bindings for second key
  registerSubmotion go_definition, 'GO', 'Go to the beginning of visible document', () ->
    return (cursor, options) ->
      cursor.visibleHome options
  registerSubmotion go_definition, 'PARENT', 'Go to the parent of current line', () ->
    return (cursor, options) ->
      cursor.parent options
  registerSubmotion go_definition, 'MARK', 'Go to the mark indicated by the cursor, if it exists', () ->
    return (cursor, options) ->
      do cursor.goMark
  registerMotion 'GO', 'Various commands for navigation (operator)', go_definition

  actionDefinitions =

    DELETE:
      description: 'Delete (operator)'
      visual_line: do visual_line_mode_delete_fn
      visual: do visual_mode_delete_fn
      bindings:
        DELETE:
          description: 'Delete blocks'
          normal: () ->
            @view.delBlocksAtCursor @repeat, {addNew: false}
            do @keyStream.save
        MOTION:
          description: 'Delete from cursor with motion'
          normal: (motion) ->
            cursor = do @view.cursor.clone
            for i in [1..@repeat]
              motion cursor, {pastEnd: true, pastEndWord: true}

            @view.deleteBetween @view.cursor, cursor, { yank: true }
            do @keyStream.save
        MARK:
          description: 'Delete mark at cursor'
          normal: () ->
            @view.setMark @view.cursor.row, ''
            do @keyStream.save
    CHANGE:
      description: 'Change (operator)'
      visual_line: () ->
        @view.delBlocks @parent, @row_start_i, @num_rows, {addNew: true}
        @view.setMode MODES.INSERT
      visual: () ->
        options = {includeEnd: true, yank: true, cursor: {pastEnd: true}}
        @view.deleteBetween @view.cursor, @view.anchor, options
        @view.setMode MODES.INSERT
      bindings:
        CHANGE:
          description: 'Delete blocks, and enter insert mode'
          normal: () ->
            @view.setMode MODES.INSERT
            @view.delBlocksAtCursor @repeat, {addNew: true}
        MOTION:
          description: 'Delete from cursor with motion, and enter insert mode'
          normal: (motion) ->
            cursor = do @view.cursor.clone
            for i in [1..@repeat]
              motion cursor, {pastEnd: true, pastEndWord: true}

            @view.setMode MODES.INSERT
            @view.deleteBetween @view.cursor, cursor, {yank: true, cursor: { pastEnd: true }}

    YANK:
      description: 'Yank (operator)'
      visual_line: () ->
        @view.yankBlocks @row_start, @num_rows
        @view.setMode MODES.NORMAL
        do @keyStream.forget
      visual: () ->
        options = {includeEnd: true}
        @view.yankBetween @view.cursor, @view.anchor, options
        @view.setMode MODES.NORMAL
        do @keyStream.forget
      bindings:
        YANK:
          description: 'Yank blocks'
          normal: () ->
            @view.yankBlocksAtCursor @repeat
            do @keyStream.forget
        MOTION:
          description: 'Yank from cursor with motion'
          normal: (motion) ->
            cursor = do @view.cursor.clone
            for i in [1..@repeat]
              motion cursor, {pastEnd: true, pastEndWord: true}

            @view.yankBetween @view.cursor, cursor, {}
            do @keyStream.forget

  registerSubaction = (
    mainDefinition,
    name,
    description,
    modes,
    definition
  ) ->
    if not (name of mainDefinition)
      mainDefinition[name] = {}
    mainDefinition[name].name = name
    mainDefinition[name].description = description
    for mode in modes
      mainDefinition[name][mode] = definition

  registerAction = registerSubaction.bind @, actionDefinitions

  registerAction 'MOTION', 'Move the cursor', ['normal'], (motion) ->
    for i in [1..@repeat]
      motion @view.cursor, {}
    do @keyStream.forget
  registerAction 'MOTION', 'Move the cursor', ['insert'], (motion) ->
    motion @view.cursor, {pastEnd: true}
  registerAction 'MOTION', 'Move the cursor', ['visual'], (motion) ->
    # this is necessary until we figure out multiline
    tmp = do @view.cursor.clone
    for i in [1..@repeat]
      motion tmp, {pastEnd: true}

    if tmp.row != @view.cursor.row # only allow same-row movement
      @view.showMessage "Visual mode currently only works on one line", {text_class: 'error'}
    else
      @view.cursor.from tmp
  registerAction 'MOTION', 'Move the cursor', ['visual_line'], (motion) ->
    for i in [1..@repeat]
      motion @view.cursor, {pastEnd: true}
  registerAction 'MOTION', 'Move the cursor', ['mark'], (motion) ->
    motion @view.markview.cursor, {pastEnd: true}
  registerAction 'MOTION', 'Move the cursor', ['search'], (motion) ->
    motion @view.menu.view.cursor, {pastEnd: true}

  registerAction 'HELP', 'Show/hide key bindings (edit in settings)', ['normal'], () ->
    do @view.toggleBindingsDiv
    do @keyStream.forget

  registerAction 'ZOOM_IN', 'Zoom in by one level', ['normal', 'insert'], () ->
    do @view.rootDown
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction 'ZOOM_OUT', 'Zoom out by one level', ['normal', 'insert'], () ->
    do @view.rootUp
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction 'ZOOM_IN_ALL', 'Zoom in onto cursor', ['normal', 'insert'], () ->
    do @view.rootInto
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction 'ZOOM_OUT_ALL', 'Zoom out to home', ['normal', 'insert'], () ->
    do @view.reroot
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction 'INDENT_RIGHT', 'Indent row right', ['normal'], () ->
    do @view.indent
    do @keyStream.save
  registerAction 'INDENT_RIGHT', 'Indent row right', ['insert'], () ->
    do @view.indent
  # NOTE: this matches block indent behavior, in visual line
  registerAction 'INDENT_RIGHT', 'Indent row right', ['visual_line'], (do visual_line_indent)
  registerAction 'INDENT_LEFT', 'Indent row left', ['normal'], () ->
    do @view.unindent
    do @keyStream.save
  registerAction 'INDENT_LEFT', 'Indent row left', ['insert'], () ->
    do @view.unindent
  # NOTE: this matches block indent behavior, in visual line
  registerAction 'INDENT_LEFT', 'Indent row left', ['visual_line'], (do visual_line_unindent)

  registerAction 'MOVE_BLOCK_RIGHT', 'Move block right', ['normal'], () ->
    @view.indentBlocks @view.cursor.row, @repeat
    do @keyStream.save
  registerAction 'MOVE_BLOCK_RIGHT', 'Move block right', ['insert'], () ->
    @view.indentBlocks @view.cursor.row, 1
  registerAction 'MOVE_BLOCK_RIGHT', 'Move block right', ['visual_line'], (do visual_line_indent)
  registerAction 'MOVE_BLOCK_LEFT', 'Move block left', ['normal'], () ->
    @view.unindentBlocks @view.cursor.row, @repeat
    do @keyStream.save
  registerAction 'MOVE_BLOCK_LEFT', 'Move block left', ['insert'], () ->
    @view.unindentBlocks @view.cursor.row, 1
  registerAction 'MOVE_BLOCK_LEFT', 'Move block left', ['visual_line'], (do visual_line_unindent)
  registerAction 'MOVE_BLOCK_DOWN', 'Move block down', ['normal', 'insert'], () ->
    do @view.swapDown
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction 'MOVE_BLOCK_UP', 'Move block up', ['normal', 'insert'], () ->
    do @view.swapUp
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction 'TOGGLE_FOLD', 'Toggle whether a block is folded', ['normal', 'insert'], () ->
    do @view.toggleCurBlock
    if @mode == MODES.NORMAL
      do @keyStream.save

  # content-based navigation

  registerAction 'SEARCH', 'Search', ['normal'], () ->
    @view.setMode MODES.SEARCH
    @view.menu = new Menu @view.menuDiv, (chars) =>
      results = []

      selectRow = (row) ->
        @view.rootInto row

      for found in @view.find chars
        row = found.row

        highlights = {}
        for i in found.matches
          highlights[i] = true

        results.push {
          contents: @view.data.getLine row
          renderOptions: {
            highlights: highlights
          }
          fn: selectRow.bind(@, row)
        }
      return results

    do @view.menu.update
    do @keyStream.forget

  registerAction 'MARK', 'Mark a line', ['normal'], () ->
    @view.setMode MODES.MARK
    do @keyStream.forget
  registerAction 'FINISH_MARK', 'Finish typing mark', ['mark'], () ->
    mark = (do @view.markview.curText).join ''
    @view.setMark @view.markrow, mark
    @view.setMode MODES.NORMAL
    do @keyStream.save
  registerAction 'MARK_SEARCH', 'Go to (search for) a mark', ['normal'], () ->
    @view.setMode MODES.SEARCH
    @view.menu = new Menu @view.menuDiv, (chars) =>
      results = []

      selectRow = (row) ->
        @view.rootInto row

      text = chars.join('')
      for found in @view.data.findMarks text
        row = found.row
        mark = found.mark
        results.push {
          contents: @view.data.getLine row
          renderOptions: {
            mark: mark
          }
          fn: selectRow.bind(@, row)
        }
      return results

    do @view.menu.update
    do @keyStream.forget
  registerAction 'JUMP_PREVIOUS', 'Jump to previous location', ['normal'], () ->
    do @view.jumpPrevious
    do @keyStream.forget
  registerAction 'JUMP_NEXT', 'Jump to next location', ['normal'], () ->
    do @view.jumpNext
    do @keyStream.forget

  # traditional vim stuff
  registerAction 'INSERT', 'Insert at character', ['normal'], () ->
    @view.setMode MODES.INSERT
  registerAction 'INSERT_AFTER', 'Insert after character', ['normal'], () ->
    @view.setMode MODES.INSERT
    @view.cursor.right {pastEnd: true}
  registerAction 'INSERT_HOME', 'Insert at beginning of line', ['normal'], () ->
    @view.setMode MODES.INSERT
    do @view.cursor.home
  registerAction 'INSERT_END', 'Insert after end of line', ['normal'], () ->
    @view.setMode MODES.INSERT
    @view.cursor.end {pastEnd: true}
  registerAction 'INSERT_LINE_BELOW', 'Insert on new line after current line', ['normal'], () ->
    @view.setMode MODES.INSERT
    do @view.newLineBelow
  registerAction 'INSERT_LINE_ABOVE', 'Insert on new line before current line', ['normal'], () ->
    @view.setMode MODES.INSERT
    do @view.newLineAbove

  # TODO: visual and visual_line mode
  registerAction 'REPLACE', 'Replace character', ['normal'], () ->
    key = do @keyStream.dequeue
    if key == null then return do @keyStream.wait
    @view.replaceCharsAfterCursor key, @repeat, {setCursor: 'end'}
    do @keyStream.save

  registerAction 'UNDO', 'Undo', ['normal'], () ->
    for i in [1..@repeat]
      do @view.undo
    do @keyStream.forget
  registerAction 'REDO', 'Redo', ['normal'], () ->
    for i in [1..@repeat]
      do @view.redo
    do @keyStream.forget
  registerAction 'REPLAY', 'Replay last command', ['normal'], () ->
    for i in [1..@repeat]
      @keyHandler.playRecording @keyStream.lastSequence
      do @view.save
    do @keyStream.forget
  registerAction 'RECORD_MACRO', 'Begin/stop recording a macro', ['normal'], () ->
    if @keyHandler.recording.stream == null
      key = do @keyStream.dequeue
      if key == null then return do @keyStream.wait
      @keyHandler.beginRecording key
    else
      # pop off the RECORD_MACRO itself
      do @keyHandler.recording.stream.queue.pop
      do @keyHandler.finishRecording
    do @keyStream.forget
  registerAction 'PLAY_MACRO', 'Play a macro', ['normal'], () ->
    key = do @keyStream.dequeue
    if key == null then return do @keyStream.wait
    recording = @keyHandler.macros[key]
    if recording == undefined then return do @keyStream.forget
    for i in [1..@repeat]
      @keyHandler.playRecording recording
    # save the macro-playing sequence itself
    do @keyStream.save

  registerAction 'DELETE_CHAR', 'Delete character at the cursor (i.e. del key)', ['normal'], () ->
    @view.delCharsAfterCursor @repeat, {yank: true}
    do @keyStream.save
  # behaves like row delete, in visual line
  registerAction 'DELETE_CHAR', 'Delete character at the cursor (i.e. del key)', ['visual'], (do visual_mode_delete_fn)
  registerAction 'DELETE_CHAR', 'Delete character at the cursor (i.e. del key)', ['visual_line'], (do visual_line_mode_delete_fn)
  registerAction 'DELETE_CHAR', 'Delete character at the cursor (i.e. del key)', ['insert'], () ->
    @view.delCharsAfterCursor 1
  registerAction 'DELETE_CHAR', 'Delete character at the cursor (i.e. del key)', ['mark'], () ->
    @view.markview.delCharsAfterCursor 1
  registerAction 'DELETE_CHAR', 'Delete character at the cursor (i.e. del key)', ['search'], () ->
    @view.menu.view.delCharsAfterCursor 1

  registerAction 'DELETE_LAST_CHAR', 'Delete last character (i.e. backspace key)', ['normal'], () ->
    num = Math.min @view.cursor.col, @repeat
    if num > 0
      @view.delCharsBeforeCursor num, {yank: true}
    do @keyStream.save
  # behaves like row delete, in visual line
  registerAction 'DELETE_LAST_CHAR', 'Delete last character (i.e. backspace key)', ['visual'], (do visual_mode_delete_fn)
  registerAction 'DELETE_LAST_CHAR', 'Delete last character (i.e. backspace key)', ['visual_line'], (do visual_line_mode_delete_fn)
  registerAction 'DELETE_LAST_CHAR', 'Delete last character (i.e. backspace key)', ['insert'], () ->
    do @view.deleteAtCursor
  registerAction 'DELETE_LAST_CHAR', 'Delete last character (i.e. backspace key)', ['mark'], () ->
    do @view.markview.deleteAtCursor
  registerAction 'DELETE_LAST_CHAR', 'Delete last character (i.e. backspace key)', ['search'], () ->
    do @view.menu.view.deleteAtCursor

  registerAction 'CHANGE_CHAR', 'Change character', ['normal'], () ->
    @view.delCharsAfterCursor 1, {cursor: {pastEnd: true}}, {yank: true}
    @view.setMode MODES.INSERT

  # TODO: something like this would be nice...
  # registerActionAsMacro 'DELETE_TO_HOME', ['DELETE', 'HOME']
  registerAction 'DELETE_TO_HOME', 'Delete to the beginning of the line', ['normal', 'insert'], () ->
    options = {
      cursor: {}
      yank: true
    }
    if @mode == MODES.INSERT
      options.cursor.pastEnd = true
    @view.deleteBetween @view.cursor, @view.cursor.clone().home(options.cursor), options
    if @mode == MODES.NORMAL
      do @keyStream.save

  # macro: ['DELETE', 'END']
  registerAction 'DELETE_TO_END', 'Delete to the end of the line', ['normal', 'insert'], () ->
    options = {
      yank: true
      cursor: {}
      includeEnd: true
    }
    if @mode == MODES.INSERT
      options.cursor.pastEnd = true
    @view.deleteBetween @view.cursor, @view.cursor.clone().end(options.cursor), options
    if @mode == MODES.NORMAL
      do @keyStream.save

  # define action as... macro: ['DELETE', 'BEGINNING_WWORD']
  registerAction 'DELETE_LAST_WORD', 'Delete to the beginning of the previous word', ['normal', 'insert'], () ->
    options = {
      yank: true
      cursor: {}
      includeEnd: true
    }
    if @mode == MODES.INSERT
      options.cursor.pastEnd = true
    @view.deleteBetween @view.cursor, @view.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}), options
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction 'PASTE_AFTER', 'Paste after cursor', ['normal'], () ->
    do @view.pasteAfter
    do @keyStream.save
  # NOTE: paste after doesn't make sense for insert mode
  registerAction 'PASTE_BEFORE', 'Paste before cursor', ['normal'], () ->
    @view.pasteBefore {}
    do @keyStream.save
  registerAction 'PASTE_BEFORE', 'Paste before cursor', ['insert'], () ->
    @view.pasteBefore {cursor: {pastEnd: true}}

  registerAction 'JOIN_LINE', 'Join current line with line below', ['normal'], () ->
    do @view.joinAtCursor
    do @keyStream.save
  registerAction 'SPLIT_LINE', 'Split line at cursor (i.e. enter key)', ['normal', 'insert'], () ->
    do @view.newLineAtCursor
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction 'SCROLL_DOWN', 'Scroll half window down', ['normal', 'insert'], () ->
    @view.scrollPages 0.5
    if @mode == MODES.NORMAL
      do @keyStream.forget
    # TODO: if insert, forget *only this*

  registerAction 'SCROLL_UP', 'Scroll half window up', ['normal', 'insert'], () ->
    @view.scrollPages -0.5
    if @mode == MODES.NORMAL
      do @keyStream.forget

  # for everything but normal mode
  registerAction 'EXIT_MODE', 'Exit back to normal mode', ['visual', 'visual_line', 'search', 'mark'], () ->
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  registerAction 'EXIT_MODE', 'Exit back to normal mode', ['insert'], () ->
    do @view.cursor.left
    @view.setMode MODES.NORMAL
    # unlike other modes, esc in insert mode keeps changes
    do @keyStream.save

  # for visual and visual line mode
  registerAction 'ENTER_VISUAL', 'Enter visual mode', ['normal'], () ->
    @view.setMode MODES.VISUAL
  registerAction 'ENTER_VISUAL_LINE', 'Enter visual line mode', ['normal'], () ->
    @view.setMode MODES.VISUAL_LINE
  registerAction 'SWAP_CURSOR', 'Swap cursor to other end of selection, in visual and visual line mode', ['visual', 'visual_line'], () ->
    tmp = do @view.anchor.clone
    @view.anchor.from @view.cursor
    @view.cursor.from tmp
    do @keyStream.save

  # for menu mode

  registerAction 'MENU_SELECT', 'Select current menu selection', ['search'], () ->
    do @view.menu.select
    @view.setMode MODES.NORMAL
  registerAction 'MENU_UP', 'Select previous menu selection', ['search'], () ->
    do @view.menu.up
  registerAction 'MENU_DOWN', 'Select next menu selection', ['search'], () ->
    do @view.menu.down

  # FORMATTING

  text_format_normal = (property) ->
    return () ->
      @view.toggleRowProperty property
      do @keyStream.save

  text_format_insert = (property) ->
    return () ->
      @view.cursor.toggleProperty property

  text_format_visual_line = (property) ->
    return () ->
      rows = @view.data.getChildRange @parent, @row_start_i, @row_end_i
      @view.toggleRowsProperty property, rows
      @view.setMode MODES.NORMAL
      do @keyStream.save

  text_format_visual = (property) ->
    return () ->
      @view.toggleRowPropertyBetween property, @view.cursor, @view.anchor, {includeEnd: true}
      @view.setMode MODES.NORMAL
      do @keyStream.save

  registerAction 'BOLD', 'Bold text', ['normal'], (text_format_normal 'bold')
  registerAction 'BOLD', 'Bold text', ['insert'], (text_format_insert 'bold')
  registerAction 'BOLD', 'Bold text', ['visual'], (text_format_visual 'bold')
  registerAction 'BOLD', 'Bold text', ['visual_line'], (text_format_visual_line 'bold')
  registerAction 'ITALIC', 'Italicize text', ['normal'], (text_format_normal 'italic')
  registerAction 'ITALIC', 'Italicize text', ['insert'], (text_format_insert 'italic')
  registerAction 'ITALIC', 'Italicize text', ['visual'], (text_format_visual 'italic')
  registerAction 'ITALIC', 'Italicize text', ['visual_line'], (text_format_visual_line 'italic')
  registerAction 'UNDERLINE', 'Underline text', ['normal'], (text_format_normal 'underline')
  registerAction 'UNDERLINE', 'Underline text', ['insert'], (text_format_insert 'underline')
  registerAction 'UNDERLINE', 'Underline text', ['visual'], (text_format_visual 'underline')
  registerAction 'UNDERLINE', 'Underline text', ['visual_line'], (text_format_visual_line 'underline')
  registerAction 'STRIKETHROUGH', 'Strike through text', ['normal'], (text_format_normal 'strikethrough')
  registerAction 'STRIKETHROUGH', 'Strike through text', ['insert'], (text_format_insert 'strikethrough')
  registerAction 'STRIKETHROUGH', 'Strike through text', ['visual'], (text_format_visual 'strikethrough')
  registerAction 'STRIKETHROUGH', 'Strike through text', ['visual_line'], (text_format_visual_line 'strikethrough')

  module?.exports = {
    actions: actionDefinitions
    motions: motionDefinitions
  }
  window?.keyDefinitions = {
    actions: actionDefinitions
    motions: motionDefinitions
  }
)()
