if module?
  global.constants = require('./constants.coffee')

###
keyDefinitions defines the set of possible commands.
Each command has a name, which the keyDefinitions dictionary maps to a definition,
which describes what the command should do in various modes.

Each definition has the following required fields:
    display:
        a string used for display in keybindings help screen
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

  get_swap_cursor_fn = () ->
    return () ->
      tmp = do @view.anchor.clone
      @view.anchor.from @view.cursor
      @view.cursor.from tmp
      do @keyStream.save

  exit_normal_fn = () ->
    return () ->
      @view.setMode MODES.NORMAL
      do @keyStream.forget

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

  keyDefinitions =
    MOTION:
      display: 'Move the cursor'
      normal: (motion) ->
        for i in [1..@repeat]
          motion @view.cursor, {}
        do @keyStream.forget
      insert: (motion) ->
        motion @view.cursor, {pastEnd: true}
      visual: (motion) ->
        # this is necessary until we figure out multiline
        tmp = do @view.cursor.clone

        for i in [1..@repeat]
          motion tmp, {pastEnd: true}

        if tmp.row != @view.cursor.row # only allow same-row movement
          @view.showMessage "Visual mode currently only works on one line", {text_class: 'error'}
        else
          @view.cursor.from tmp
      visual_line: (motion) ->
        for i in [1..@repeat]
          motion @view.cursor, {pastEnd: true}
      mark: (motion) ->
        motion @view.markview.cursor, {pastEnd: true}
      search: (motion) ->
        motion @view.menu.view.cursor, {pastEnd: true}

    HELP:
      display: 'Show/hide key bindings (edit in settings)'
      normal: () ->
        do @view.toggleBindingsDiv
        do @keyStream.forget
    ZOOM_IN:
      display: 'Zoom in by one level'
      normal: () ->
        do @view.rootDown
        do @keyStream.save
      insert: () ->
        do @view.rootDown
    ZOOM_OUT:
      display: 'Zoom out by one level'
      normal: () ->
        do @view.rootUp
        do @keyStream.save
      insert: () ->
        do @view.rootUp
    ZOOM_IN_ALL:
      display: 'Zoom in onto cursor'
      normal: () ->
        do @view.rootInto
        do @keyStream.save
      insert: () ->
        do @view.rootInto
    ZOOM_OUT_ALL:
      display: 'Zoom out to home'
      normal: () ->
        do @view.reroot
        do @keyStream.save
      insert: () ->
        do @view.reroot

    INDENT_RIGHT:
      display: 'Indent row right'
      normal: () ->
        do @view.indent
        do @keyStream.save
      insert: () ->
        do @view.indent
      # NOTE: this matches block indent behavior, in visual line
      visual_line: do visual_line_indent
    INDENT_LEFT:
      display: 'Indent row left'
      normal: () ->
        do @view.unindent
        do @keyStream.save
      insert: () ->
        do @view.unindent
      # NOTE: this matches block indent behavior, in visual line
      visual_line: do visual_line_unindent
    MOVE_BLOCK_RIGHT:
      display: 'Move block right'
      normal: () ->
        @view.indentBlocks @view.cursor.row, @repeat
        do @keyStream.save
      insert: () ->
        @view.indentBlocks @view.cursor.row, 1
      visual_line: do visual_line_indent
    MOVE_BLOCK_LEFT:
      display: 'Move block left'
      normal: () ->
        @view.unindentBlocks @view.cursor.row, @repeat
        do @keyStream.save
      insert: () ->
        @view.unindentBlocks @view.cursor.row, 1
      visual_line: do visual_line_unindent
    MOVE_BLOCK_DOWN:
      display: 'Move block down'
      normal: () ->
        do @view.swapDown
        do @keyStream.save
      insert: () ->
        do @view.swapDown
    MOVE_BLOCK_UP:
      display: 'Move block up'
      normal: () ->
        do @view.swapUp
        do @keyStream.save
      insert: () ->
        do @view.swapUp

    TOGGLE_FOLD:
      display: 'Toggle whether a block is folded'
      normal: () ->
        do @view.toggleCurBlock
        do @keyStream.save
      insert: () ->
        do @view.toggleCurBlock

    # content-based navigation

    SEARCH:
      display: 'Search'
      normal: () ->
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

    MARK:
      display: 'Mark a line'
      normal: () ->
        @view.setMode MODES.MARK
        do @keyStream.forget
    FINISH_MARK:
      display: 'Finish typing mark'
      mark: () ->
        mark = (do @view.markview.curText).join ''
        @view.setMark @view.markrow, mark
        @view.setMode MODES.NORMAL
        do @keyStream.save
    MARK_SEARCH:
      display: 'Go to (search for) a mark'
      normal: () ->
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
    JUMP_PREVIOUS:
      display: 'Jump to previous location'
      normal: () ->
        do @view.jumpPrevious
        do @keyStream.forget
    JUMP_NEXT:
      display: 'Jump to next location'
      normal: () ->
        do @view.jumpNext
        do @keyStream.forget

    # traditional vim stuff
    INSERT:
      display: 'Insert at character'
      normal: () ->
        @view.setMode MODES.INSERT
    INSERT_AFTER:
      display: 'Insert after character'
      normal: () ->
        @view.setMode MODES.INSERT
        @view.cursor.right {pastEnd: true}
    INSERT_HOME:
      display: 'Insert at beginning of line'
      normal: () ->
        @view.setMode MODES.INSERT
        do @view.cursor.home
    INSERT_END:
      display: 'Insert after end of line'
      normal: () ->
        @view.setMode MODES.INSERT
        @view.cursor.end {pastEnd: true}
    INSERT_LINE_BELOW:
      display: 'Insert on new line after current line'
      normal: () ->
        @view.setMode MODES.INSERT
        do @view.newLineBelow
    INSERT_LINE_ABOVE:
      display: 'Insert on new line before current line'
      normal: () ->
        @view.setMode MODES.INSERT
        do @view.newLineAbove
    REPLACE:
      # TODO: visual and visual_line mode
      display: 'Replace character'
      normal: () ->
        key = do @keyStream.dequeue
        if key == null then return do @keyStream.wait
        @view.replaceCharsAfterCursor key, @repeat, {setCursor: 'end'}
        do @keyStream.save

    UNDO:
      display: 'Undo'
      normal: () ->
        for i in [1..@repeat]
          do @view.undo
        do @keyStream.forget
    REDO:
      display: 'Redo'
      normal: () ->
        for i in [1..@repeat]
          do @view.redo
        do @keyStream.forget
    REPLAY:
      display: 'Replay last command'
      normal: () ->
        for i in [1..@repeat]
          @keyHandler.playRecording @keyStream.lastSequence
          do @view.save
        do @keyStream.forget
    RECORD_MACRO:
      display: 'Begin/stop recording a macro'
      normal: () ->
        if @keyHandler.recording.stream == null
          key = do @keyStream.dequeue
          if key == null then return do @keyStream.wait
          @keyHandler.beginRecording key
        else
          # pop off the RECORD_MACRO itself
          do @keyHandler.recording.stream.queue.pop
          do @keyHandler.finishRecording
        do @keyStream.forget
    PLAY_MACRO:
      display: 'Play a macro'
      normal: () ->
        key = do @keyStream.dequeue
        if key == null then return do @keyStream.wait
        recording = @keyHandler.macros[key]
        if recording == undefined then return do @keyStream.forget
        for i in [1..@repeat]
          @keyHandler.playRecording recording
        # save the macro-playing sequence itself
        do @keyStream.save

    DELETE_CHAR:
      display: 'Delete character at the cursor (i.e. del key)'
      # behaves like row delete, in visual line
      visual_line: do visual_line_mode_delete_fn
      visual: do visual_mode_delete_fn
      normal: () ->
        @view.delCharsAfterCursor @repeat, {yank: true}
        do @keyStream.save
      insert: () ->
        @view.delCharsAfterCursor 1
      mark: () ->
        @view.markview.delCharsAfterCursor 1
      search: () ->
        @view.menu.view.delCharsAfterCursor 1
    DELETE_LAST_CHAR:
      display: 'Delete last character (i.e. backspace key)'
      # behaves like row delete, in visual line
      visual_line: do visual_line_mode_delete_fn
      visual: do visual_mode_delete_fn
      normal: () ->
        num = Math.min @view.cursor.col, @repeat
        if num > 0
          @view.delCharsBeforeCursor num, {yank: true}
        do @keyStream.save
      insert: () ->
        do @view.deleteAtCursor
      mark: () ->
        do @view.markview.deleteAtCursor
      search: () ->
        do @view.menu.view.deleteAtCursor

    CHANGE_CHAR:
      display: 'Change character'
      normal: () ->
        @view.delCharsAfterCursor 1, {cursor: {pastEnd: true}}, {yank: true}
        @view.setMode MODES.INSERT
    DELETE_TO_HOME:
      display: 'Delete to the beginning of the line'
      # TODO: something like this would be nice...
      # macro: ['DELETE', 'HOME']
      normal: () ->
        options = {
          cursor: {}
          yank: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().home(options.cursor), options
        do @keyStream.save
      insert: () ->
        options = {
          cursor: {pastEnd: true}
          yank: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().home(options.cursor), options
    DELETE_TO_END:
      display: 'Delete to the end of the line'
      # macro: ['DELETE', 'END']
      normal: () ->
        options = {
          yank: true
          cursor: {}
          includeEnd: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().end(options.cursor), options
        do @keyStream.save
      insert: () ->
        options = {
          yank: true
          cursor: {pastEnd: true}
          includeEnd: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().end(options.cursor), options
    DELETE_LAST_WORD:
      display: 'Delete to the beginning of the previous word'
      # macro: ['DELETE', 'BEGINNING_WWORD']
      normal: () ->
        options = {
          yank: true
          cursor: {}
          includeEnd: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}), options
        do @keyStream.save
      insert: () ->
        options = {
          yank: true
          cursor: {pastEnd: true}
          includeEnd: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}), options

    DELETE:
      display: 'Delete (operator)'
      visual_line: do visual_line_mode_delete_fn
      visual: do visual_mode_delete_fn
      bindings:
        DELETE:
          display: 'Delete blocks'
          normal: () ->
            @view.delBlocksAtCursor @repeat, {addNew: false}
            do @keyStream.save
        MOTION:
          display: 'Delete from cursor with motion'
          normal: (motion) ->
            cursor = do @view.cursor.clone
            for i in [1..@repeat]
              motion cursor, {pastEnd: true, pastEndWord: true}

            @view.deleteBetween @view.cursor, cursor, { yank: true }
            do @keyStream.save
        MARK:
          display: 'Delete mark at cursor'
          normal: () ->
            @view.setMark @view.cursor.row, ''
            do @keyStream.save
    CHANGE:
      display: 'Change (operator)'
      visual_line: () ->
        @view.delBlocks @parent, @row_start_i, @num_rows, {addNew: true}
        @view.setMode MODES.INSERT
      visual: () ->
        options = {includeEnd: true, yank: true, cursor: {pastEnd: true}}
        @view.deleteBetween @view.cursor, @view.anchor, options
        @view.setMode MODES.INSERT
      bindings:
        CHANGE:
          display: 'Delete blocks, and enter insert mode'
          normal: () ->
            @view.setMode MODES.INSERT
            @view.delBlocksAtCursor @repeat, {addNew: true}
        MOTION:
          display: 'Delete from cursor with motion, and enter insert mode'
          normal: (motion) ->
            cursor = do @view.cursor.clone
            for i in [1..@repeat]
              motion cursor, {pastEnd: true, pastEndWord: true}

            @view.setMode MODES.INSERT
            @view.deleteBetween @view.cursor, cursor, {yank: true, cursor: { pastEnd: true }}

    YANK:
      display: 'Yank (operator)'
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
          display: 'Yank blocks'
          normal: () ->
            @view.yankBlocksAtCursor @repeat
            do @keyStream.forget
        MOTION:
          display: 'Yank from cursor with motion'
          normal: (motion) ->
            cursor = do @view.cursor.clone
            for i in [1..@repeat]
              motion cursor, {pastEnd: true, pastEndWord: true}

            @view.yankBetween @view.cursor, cursor, {}
            do @keyStream.forget
    PASTE_AFTER:
      display: 'Paste after cursor'
      normal: () ->
        do @view.pasteAfter
        do @keyStream.save
      # NOTE: paste after doesn't make sense for insert mode
    PASTE_BEFORE:
      display: 'Paste before cursor'
      normal: () ->
        @view.pasteBefore {}
        do @keyStream.save
      insert: () ->
        @view.pasteBefore {cursor: {pastEnd: true}}

    JOIN_LINE:
      display: 'Join current line with line below'
      normal: () ->
        do @view.joinAtCursor
        do @keyStream.save
    SPLIT_LINE:
      display: 'Split line at cursor (i.e. enter key)'
      normal: () ->
        do @view.newLineAtCursor
        do @keyStream.save
      insert: () ->
        do @view.newLineAtCursor

    SCROLL_DOWN:
      display: 'Scroll half window down'
      normal: () ->
        @view.scrollPages 0.5
        do @keyStream.forget
      insert: () ->
        @view.scrollPages 0.5
    SCROLL_UP:
      display: 'Scroll half window up'
      normal: () ->
        @view.scrollPages -0.5
        do @keyStream.forget
      insert: () ->
        @view.scrollPages -0.5

    # for everything but normal mode
    EXIT_MODE:
      display: 'Exit back to normal mode'
      visual_line: do exit_normal_fn
      visual: do exit_normal_fn
      search: do exit_normal_fn
      mark: do exit_normal_fn
      insert: () ->
        do @view.cursor.left
        @view.setMode MODES.NORMAL
        # unlike other modes, esc in insert mode keeps changes
        do @keyStream.save

    # for visual mode
    ENTER_VISUAL:
      display: 'Enter visual mode'
      normal: () ->
        @view.setMode MODES.VISUAL
    ENTER_VISUAL_LINE:
      display: 'Enter visual line mode'
      normal: () ->
        @view.setMode MODES.VISUAL_LINE
    SWAP_CURSOR:
      display: 'Swap cursor to other end of selection, in visual and visual line mode'
      visual: do get_swap_cursor_fn
      visual_line: do get_swap_cursor_fn

    # for menu mode
    MENU_SELECT:
      display: 'Select current menu selection'
      search: () ->
        do @view.menu.select
        @view.setMode MODES.NORMAL
    MENU_UP:
      display: 'Select previous menu selection'
      search: () ->
        do @view.menu.up
    MENU_DOWN:
      display: 'Select next menu selection'
      search: () ->
        do @view.menu.down

    # FORMATTING
    BOLD:
      display: 'Bold text'
      normal: text_format_normal 'bold'
      insert: text_format_insert 'bold'
      visual_line: text_format_visual_line 'bold'
      visual: text_format_visual 'bold'
    ITALIC:
      display: 'Italicize text'
      normal: text_format_normal 'italic'
      insert: text_format_insert 'italic'
      visual_line: text_format_visual_line 'italic'
      visual: text_format_visual 'italic'

    UNDERLINE:
      display: 'Underline text'
      normal: text_format_normal 'underline'
      insert: text_format_insert 'underline'
      visual_line: text_format_visual_line 'underline'
      visual: text_format_visual 'underline'

    STRIKETHROUGH:
      display: 'Strike through text'
      normal: text_format_normal 'strikethrough'
      insert: text_format_insert 'strikethrough'
      visual_line: text_format_visual_line 'strikethrough'
      visual: text_format_visual 'strikethrough'

  module?.exports = {
    keyDefinitions: keyDefinitions
    motionDefinitions: motionDefinitions
  }
  window?.keyDefinitions = keyDefinitions
  window?.motionDefinitions = motionDefinitions
)()
