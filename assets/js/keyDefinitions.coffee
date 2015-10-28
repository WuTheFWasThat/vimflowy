if module?
  global.constants = require('./constants.coffee')

###
keyDefinitions defines the set of possible commands.
Each command has a name, which the keyDefinitions dictionary maps to a definition,
which describes what the command should do in various modes.

Each definition has the following required fields:
    display:
        a string used for display in keybindings help screen
    motion:
        a boolean indicating whether the function is a motion (default false)
The definition should also have 1 of the following 3 fields
    fn:
        takes a view and mutates it
        if this is a motion, takes an extra cursor argument first
    continue:
        a function which takes additionally an extra key as its first argument
    bindings:
        another (recursive) set of key definitions, i.e. a dictionary from command names to definitions
It may also have:
    to_mode:
        a mode to switch to
And for menu mode functions,
    menu:
      function taking a view and chars, and
      returning a list of {contents, renderOptions, fn}
      SEE: menu.coffee

NOTE: there is a special command called 'MOTION', which is used in the bindings dictionaries
    much like if the motion boolean is true, this command always takes an extra cursor argument.
    TODO: this is a hack, and should be done more properly

For more info/context, see keyBindings.coffee
###

((exports) ->
  MODES = constants.MODES

  text_format_definition = (property) ->
    return () ->
      @view.toggleRowProperty property

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
    return () -> @view.setMode MODES.NORMAL

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

  keyDefinitions =
    HELP:
      display: 'Show/hide key bindings (edit in settings)'
      drop: true
      fn: () ->
        do @view.toggleBindingsDiv
    ZOOM_IN:
      display: 'Zoom in by one level'
      fn: () ->
        do @view.rootDown
      insert: () ->
        do @view.rootDown
    ZOOM_OUT:
      display: 'Zoom out by one level'
      fn: () ->
        do @view.rootUp
      insert: () ->
        do @view.rootUp
    ZOOM_IN_ALL:
      display: 'Zoom in onto cursor'
      fn: () ->
        do @view.rootInto
      insert: () ->
        do @view.rootInto
    ZOOM_OUT_ALL:
      display: 'Zoom out to home'
      fn: () ->
        do @view.reroot
      insert: () ->
        do @view.reroot

    INDENT_RIGHT:
      display: 'Indent row right'
      fn: () ->
        do @view.indent
      insert: () ->
        do @view.indent
      # NOTE: this matches block indent behavior, in visual line
      visual_line: do visual_line_indent
    INDENT_LEFT:
      display: 'Indent row left'
      fn: () ->
        do @view.unindent
      insert: () ->
        do @view.unindent
      # NOTE: this matches block indent behavior, in visual line
      visual_line: do visual_line_unindent
    MOVE_BLOCK_RIGHT:
      display: 'Move block right'
      fn: () ->
        @view.indentBlocks @view.cursor.row, @repeat
      insert: () ->
        @view.indentBlocks @view.cursor.row, 1
      visual_line: do visual_line_indent
    MOVE_BLOCK_LEFT:
      display: 'Move block left'
      fn: () ->
        @view.unindentBlocks @view.cursor.row, @repeat
      insert: () ->
        @view.unindentBlocks @view.cursor.row, 1
      visual_line: do visual_line_unindent
    MOVE_BLOCK_DOWN:
      display: 'Move block down'
      fn: () ->
        do @view.swapDown
      insert: () ->
        do @view.swapDown
    MOVE_BLOCK_UP:
      display: 'Move block up'
      fn: () ->
        do @view.swapUp
      insert: () ->
        do @view.swapUp

    TOGGLE_FOLD:
      display: 'Toggle whether a block is folded'
      fn: () ->
        do @view.toggleCurBlock
      insert: () ->
        do @view.toggleCurBlock

    # content-based navigation

    SEARCH:
      display: 'Search'
      drop: true
      menu: (view, chars) ->
        results = []

        selectRow = (row) ->
          view.rootInto row

        for found in view.find chars
          row = found.row

          highlights = {}
          for i in found.matches
            highlights[i] = true

          results.push {
            contents: view.data.getLine row
            renderOptions: {
              highlights: highlights
            }
            fn: selectRow.bind(@, row)
          }
        return results

    MARK:
      display: 'Mark a line'
      drop: true
      to_mode: MODES.MARK
    FINISH_MARK:
      display: 'Finish typing mark'
      to_mode: MODES.NORMAL
      mark: () ->
        mark = (do @view.markview.curText).join ''
        @view.setMark @view.markrow, mark
        @view.setMode MODES.NORMAL
        do @keyStream.save
    MARK_SEARCH:
      display: 'Go to (search for) a mark'
      drop: true
      menu: (view, chars) ->
        results = []

        selectRow = (row) ->
          view.rootInto row

        text = chars.join('')
        for found in view.data.findMarks text
          row = found.row
          mark = found.mark
          results.push {
            contents: view.data.getLine row
            renderOptions: {
              mark: mark
            }
            fn: selectRow.bind(@, row)
          }
        return results
    JUMP_PREVIOUS:
      display: 'Jump to previous location'
      drop: true
      fn: () ->
        do @view.jumpPrevious
    JUMP_NEXT:
      display: 'Jump to next location'
      drop: true
      fn: () ->
        do @view.jumpNext

    # traditional vim stuff
    INSERT:
      display: 'Insert at character'
      to_mode: MODES.INSERT
      fn: () -> return
    INSERT_AFTER:
      display: 'Insert after character'
      to_mode: MODES.INSERT
      fn: () ->
        @view.cursor.right {pastEnd: true}
    INSERT_HOME:
      display: 'Insert at beginning of line'
      to_mode: MODES.INSERT
      fn: () ->
        do @view.cursor.home
    INSERT_END:
      display: 'Insert after end of line'
      to_mode: MODES.INSERT
      fn: () ->
        @view.cursor.end {pastEnd: true}
    INSERT_LINE_BELOW:
      display: 'Insert on new line after current line'
      to_mode: MODES.INSERT
      fn: () ->
        do @view.newLineBelow
    INSERT_LINE_ABOVE:
      display: 'Insert on new line before current line'
      to_mode: MODES.INSERT
      fn: () ->
        do @view.newLineAbove
    REPLACE:
      # TODO: visual and visual_line mode
      display: 'Replace character'
      continue: (char) ->
        @view.replaceCharsAfterCursor char, @repeat, {setCursor: 'end'}

    UNDO:
      display: 'Undo'
      drop: true
      fn: () ->
        for i in [1..@repeat]
          do @view.undo
    REDO:
      display: 'Redo'
      drop: true
      fn: () ->
        for i in [1..@repeat]
          do @view.redo
    REPLAY:
      display: 'Replay last command'

    LEFT:
      display: 'Move cursor left'
      motion: true
      fn: (cursor, options) ->
        cursor.left options
    RIGHT:
      display: 'Move cursor right'
      motion: true
      fn: (cursor, options) ->
        cursor.right options
    UP:
      display: 'Move cursor up'
      motion: true
      fn: (cursor, options) ->
        cursor.up options
    DOWN:
      display: 'Move cursor down'
      motion: true
      fn: (cursor, options) ->
        cursor.down options
    HOME:
      display: 'Move cursor to beginning of line'
      motion: true
      fn: (cursor, options) ->
        cursor.home options
    END:
      display: 'Move cursor to end of line'
      motion: true
      fn: (cursor, options) ->
        cursor.end options
    BEGINNING_WORD:
      display: 'Move cursor to the first word-beginning before it'
      motion: true
      fn: (cursor, options) ->
        cursor.beginningWord {cursor: options}
    END_WORD:
      display: 'Move cursor to the first word-ending after it'
      motion: true
      fn: (cursor, options) ->
        cursor.endWord {cursor: options}
    NEXT_WORD:
      display: 'Move cursor to the beginning of the next word'
      motion: true
      fn: (cursor, options) ->
        cursor.nextWord {cursor: options}
    BEGINNING_WWORD:
      display: 'Move cursor to the first Word-beginning before it'
      motion: true
      fn: (cursor, options) ->
        cursor.beginningWord {cursor: options, whitespaceWord: true}
    END_WWORD:
      display: 'Move cursor to the first Word-ending after it'
      motion: true
      fn: (cursor, options) ->
        cursor.endWord {cursor: options, whitespaceWord: true}
    NEXT_WWORD:
      display: 'Move cursor to the beginning of the next Word'
      motion: true
      fn: (cursor, options) ->
        cursor.nextWord {cursor: options, whitespaceWord: true}
    FIND_NEXT_CHAR:
      display: 'Move cursor to next occurrence of character in line'
      motion: true
      continue: (char, cursor, options) ->
        cursor.findNextChar char, {cursor: options}
    FIND_PREV_CHAR:
      display: 'Move cursor to previous occurrence of character in line'
      motion: true
      continue: (char, cursor, options) ->
        cursor.findPrevChar char, {cursor: options}
    TO_NEXT_CHAR:
      display: 'Move cursor to just before next occurrence of character in line'
      motion: true
      continue: (char, cursor, options) ->
        cursor.findNextChar char, {cursor: options, beforeFound: true}
    TO_PREV_CHAR:
      display: 'Move cursor to just after previous occurrence of character in line'
      motion: true
      continue: (char, cursor, options) ->
        cursor.findPrevChar char, {cursor: options, beforeFound: true}

    NEXT_SIBLING:
      display: 'Move cursor to the next sibling of the current line'
      motion: true
      fn: (cursor, options) ->
        cursor.nextSibling options

    PREV_SIBLING:
      display: 'Move cursor to the previous sibling of the current line'
      motion: true
      fn: (cursor, options) ->
        cursor.prevSibling options

    EASY_MOTION:
      display: 'Jump to a visible row (based on EasyMotion)'
      motion: true
      fn: () ->
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
      continue: (char, cursor, options) ->
        if char of @view.easy_motion_mappings.key_to_id
          id = @view.easy_motion_mappings.key_to_id[char]
          row = @view.data.canonicalInstance id
          cursor.set row, 0
        @view.easy_motion_mappings = null

    GO:
      display: 'Various commands for navigation (operator)'
      motion: true
      bindings:
        GO:
          display: 'Go to the beginning of visible document'
          motion: true
          fn: (cursor, options) ->
            cursor.visibleHome options
        PARENT:
          display: 'Go to the parent of current line'
          motion: true
          fn: (cursor, options) ->
            cursor.parent options
        MARK:
          display: 'Go to the mark indicated by the cursor, if it exists'
          fn: () ->
            do @view.goMark
    GO_END:
      display: 'Go to end of visible document'
      motion: true
      fn: (cursor, options) ->
        cursor.visibleEnd options
    DELETE_CHAR:
      display: 'Delete character'
      # behaves like row delete, in visual line
      visual_line: do visual_line_mode_delete_fn
      visual: do visual_mode_delete_fn
      fn: () ->
        @view.delCharsAfterCursor @repeat, {yank: true}
    DELETE_LAST_CHAR:
      display: 'Delete last character'
      fn: () ->
        num = Math.min @view.cursor.col, @repeat
        if num > 0
          @view.delCharsBeforeCursor num, {yank: true}
    CHANGE_CHAR:
      display: 'Change character'
      to_mode: MODES.INSERT
      fn: () ->
        @view.delCharsAfterCursor 1, {cursor: {pastEnd: true}}, {yank: true}
    DELETE_TO_HOME:
      display: 'Delete to the beginning of the line'
      # TODO: something like this would be nice...
      # macro: ['DELETE', 'HOME']
      fn: () ->
        options = {
          cursor: {}
          yank: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().home(options.cursor), options
      insert: () ->
        options = {
          cursor: {pastEnd: true}
          yank: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().home(options.cursor), options
    DELETE_TO_END:
      display: 'Delete to the end of the line'
      # macro: ['DELETE', 'END']
      fn: () ->
        options = {
          yank: true
          cursor: {}
          includeEnd: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().end(options.cursor), options
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
      fn: () ->
        options = {
          yank: true
          cursor: {}
          includeEnd: true
        }
        @view.deleteBetween @view.cursor, @view.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}), options
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
          fn: () ->
            @view.delBlocksAtCursor @repeat, {addNew: false}
        MOTION:
          display: 'Delete from cursor with motion'
          fn: (cursor, options = {}) ->
            options.yank = true
            @view.deleteBetween @view.cursor, cursor, options
        MARK:
          display: 'Delete mark at cursor'
          fn: () ->
            @view.setMark @view.cursor.row, ''
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
          to_mode: MODES.INSERT
          fn: () ->
            @view.delBlocksAtCursor @repeat, {addNew: true}
        MOTION:
          display: 'Delete from cursor with motion, and enter insert mode'
          to_mode: MODES.INSERT
          fn: (cursor, options = {}) ->
            options.yank = true
            options.cursor = {pastEnd: true}
            @view.deleteBetween @view.cursor, cursor, options

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
          drop: true
          fn: () ->
            @view.yankBlocksAtCursor @repeat
        MOTION:
          display: 'Yank from cursor with motion'
          drop: true
          fn: (cursor, options = {}) ->
            @view.yankBetween @view.cursor, cursor, options
        CLONE:
          display: 'Yank blocks as a clone'
          drop: true
          fn: () ->
            @view.yankBlocksCloneAtCursor @repeat
    # TODO: after keybindings stuff is better
    # CLONE:
    #   display: 'Yank blocks as a clone'
    #   visual_line: () ->
    #     @view.yankBlocksClone @row_start, @num_rows
    #     @view.setMode MODES.NORMAL
    #     do @keyStream.forget
    PASTE_AFTER:
      display: 'Paste after cursor'
      fn: () ->
        do @view.pasteAfter
      # NOTE: paste after doesn't make sense for insert mode
    PASTE_BEFORE:
      display: 'Paste before cursor'
      fn: () ->
        @view.pasteBefore {}
      insert: () ->
        @view.pasteBefore {cursor: {pastEnd: true}}

    JOIN_LINE:
      display: 'Join current line with line below'
      fn: () ->
        do @view.joinAtCursor
    SPLIT_LINE:
      display: 'Split line at cursor (i.e. enter key)'
      fn: () ->
        do @view.newLineAtCursor
      insert: () ->
        do @view.newLineAtCursor

    SCROLL_DOWN:
      display: 'Scroll half window down'
      drop: true
      fn: () ->
        @view.scrollPages 0.5
      insert: () ->
        @view.scrollPages 0.5
    SCROLL_UP:
      display: 'Scroll half window up'
      drop: true
      fn: () ->
        @view.scrollPages -0.5
      insert: () ->
        @view.scrollPages -0.5

    RECORD_MACRO:
      display: 'Begin/stop recording a macro'
    PLAY_MACRO:
      display: 'Play a macro'

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
        do @keyStream.save

    # for visual mode
    ENTER_VISUAL:
      display: 'Enter visual mode'
      to_mode: MODES.VISUAL
      fn: () ->
        @view.anchor = do @view.cursor.clone
    ENTER_VISUAL_LINE:
      display: 'Enter visual line mode'
      to_mode: MODES.VISUAL_LINE
      fn: () ->
        @view.lineSelect = true
        @view.anchor = do @view.cursor.clone
    SWAP_CURSOR:
      display: 'Swap cursor to other end of selection, in visual and visual line mode'
      visual: do get_swap_cursor_fn
      visual_line: do get_swap_cursor_fn

    # for insert mode

    BACKSPACE:
      display: 'Delete a character before the cursor (i.e. backspace key)'
      insert: () ->
        do @view.deleteAtCursor
      mark: () ->
        do @view.markview.deleteAtCursor
      search: () ->
        do @view.menu.view.deleteAtCursor
      fn: () ->
        do @view.deleteAtCursor
    DELKEY:
      display: 'Delete a character after the cursor (i.e. del key)'
      insert: () ->
        @view.delCharsAfterCursor 1
      mark: () ->
        @view.markview.delCharsAfterCursor 1
      search: () ->
        @view.menu.view.delCharsAfterCursor 1
      fn: () ->
        @view.delCharsAfterCursor 1

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
      fn: text_format_definition 'bold'
      insert: text_format_insert 'bold'
      visual_line: text_format_visual_line 'bold'
      visual: text_format_visual 'bold'
    ITALIC:
      display: 'Italicize text'
      fn: text_format_definition 'italic'
      insert: text_format_insert 'italic'
      visual_line: text_format_visual_line 'italic'
      visual: text_format_visual 'italic'

    UNDERLINE:
      display: 'Underline text'
      fn: text_format_definition 'underline'
      insert: text_format_insert 'underline'
      visual_line: text_format_visual_line 'underline'
      visual: text_format_visual 'underline'

    STRIKETHROUGH:
      display: 'Strike through text'
      fn: text_format_definition 'strikethrough'
      insert: text_format_insert 'strikethrough'
      visual_line: text_format_visual_line 'strikethrough'
      visual: text_format_visual 'strikethrough'

  module?.exports = keyDefinitions
  window?.keyDefinitions = keyDefinitions
)()
