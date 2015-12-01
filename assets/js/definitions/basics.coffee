if module?
  global.Modes = require('../modes.coffee')
  global.keyDefinitions= require('../keyDefinitions.coffee')

(() ->
  MODES = Modes.modes

  CMD_HELP = keyDefinitions.registerCommand {
    name: 'HELP'
    default_hotkeys:
      insert_like: ['ctrl+?']
      normal_like: ['?']
  }
  keyDefinitions.registerAction [MODES.NORMAL, MODES.VISUAL, MODES.VISUAL_LINE, MODES.INSERT, MODES.MARK, MODES.SEARCH], CMD_HELP, {
    description: 'Show/hide key bindings (edit in settings)',
  }, () ->
    do @view.toggleBindingsDiv
    @keyStream.forget 1


  CMD_INSERT = keyDefinitions.registerCommand {
    name: 'INSERT'
    default_hotkeys:
      normal_like: ['i']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT, {
    description: 'Insert at character',
  }, () ->
    @view.setMode MODES.INSERT

  CMD_INSERT_AFTER = keyDefinitions.registerCommand {
    name: 'INSERT_AFTER'
    default_hotkeys:
      normal_like: ['a']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_AFTER, {
    description: 'Insert after character',
  }, () ->
    @view.setMode MODES.INSERT
    @view.cursor.right {pastEnd: true}

  CMD_INSERT_HOME = keyDefinitions.registerCommand {
    name: 'INSERT_HOME'
    default_hotkeys:
      normal_like: ['I']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_HOME, {
    description: 'Insert at beginning of line',
  }, () ->
    @view.setMode MODES.INSERT
    do @view.cursor.home

  CMD_INSERT_END = keyDefinitions.registerCommand {
    name: 'INSERT_END'
    default_hotkeys:
      normal_like: ['A']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_END, {
    description: 'Insert after end of line',
  }, () ->
    @view.setMode MODES.INSERT
    @view.cursor.end {pastEnd: true}

  CMD_INSERT_LINE_BELOW = keyDefinitions.registerCommand {
    name: 'INSERT_LINE_BELOW'
    default_hotkeys:
      normal_like: ['o']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_LINE_BELOW, {
    description: 'Insert on new line after current line',
  }, () ->
    @view.setMode MODES.INSERT
    do @view.newLineBelow

  CMD_INSERT_LINE_ABOVE = keyDefinitions.registerCommand {
    name: 'INSERT_LINE_ABOVE'
    default_hotkeys:
      normal_like: ['O']
  }
  keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_LINE_ABOVE, {
    description: 'Insert on new line before current line',
  }, () ->
    @view.setMode MODES.INSERT
    do @view.newLineAbove

  CMD_DELETE = keyDefinitions.registerCommand {
    name: 'DELETE'
    default_hotkeys:
      normal_like: ['d']
  }
  CMD_DELETE_TO_END = keyDefinitions.registerCommand {
    name: 'DELETE_TO_END'
    default_hotkeys:
      normal_like: ['D']
      insert_like: ['ctrl+k']
  }
  CMD_DELETE_TO_HOME = keyDefinitions.registerCommand {
    name: 'DELETE_TO_HOME'
    default_hotkeys:
      normal_like: []
      insert_like: ['ctrl+u']
  }
  CMD_DELETE_LAST_WORD = keyDefinitions.registerCommand {
    name: 'DELETE_LAST_WORD'
    default_hotkeys:
      normal_like: []
      insert_like: ['ctrl+w']
  }
  CMD_CHANGE = keyDefinitions.registerCommand {
    name: 'CHANGE'
    default_hotkeys:
      normal_like: ['c']
  }
  CMD_DELETE_CHAR = keyDefinitions.registerCommand {
    name: 'DELETE_CHAR'
    default_hotkeys:
      normal_like: ['x']
      insert_like: ['shift+backspace']
  }
  CMD_DELETE_LAST_CHAR = keyDefinitions.registerCommand {
    name: 'DELETE_LAST_CHAR'
    default_hotkeys:
      normal_like: ['X']
      insert_like: ['backspace']
  }
  CMD_CHANGE_CHAR = keyDefinitions.registerCommand {
    name: 'CHANGE_CHAR'
    default_hotkeys:
      normal_like: ['s']
  }
  CMD_REPLACE = keyDefinitions.registerCommand {
    name: 'REPLACE'
    default_hotkeys:
      normal_like: ['r']
  }
  CMD_YANK = keyDefinitions.registerCommand {
    name: 'YANK'
    default_hotkeys:
      normal_like: ['y']
  }
  CMD_CLONE = keyDefinitions.registerCommand {
    name: 'CLONE'
    default_hotkeys:
      normal_like: ['c']
  }
  CMD_PASTE_AFTER = keyDefinitions.registerCommand {
    name: 'PASTE_AFTER'
    default_hotkeys:
      normal_like: ['p']
  }
  CMD_PASTE_BEFORE = keyDefinitions.registerCommand {
    name: 'PASTE_BEFORE'
    default_hotkeys:
      normal_like: ['P']
      insert_like: ['ctrl+y']
  }
  CMD_JOIN_LINE = keyDefinitions.registerCommand {
    name: 'JOIN_LINE'
    default_hotkeys:
      normal_like: ['J']
  }
  CMD_SPLIT_LINE = keyDefinitions.registerCommand {
    name: 'SPLIT_LINE'
    default_hotkeys:
      normal_like: ['K']
      insert_like: ['enter']
  }


  CMD_TOGGLE_FOLD = keyDefinitions.registerCommand {
    name: 'TOGGLE_FOLD'
    default_hotkeys:
      normal_like: ['z']
      insert_like: ['ctrl+z']
  }
  CMD_SCROLL_DOWN = keyDefinitions.registerCommand {
    name: 'SCROLL_DOWN'
    default_hotkeys:
      all: ['page down']
      normal_like: ['ctrl+d']
      insert_like: ['ctrl+down']
  }
  CMD_SCROLL_UP = keyDefinitions.registerCommand {
    name: 'SCROLL_UP'
    default_hotkeys:
      all: ['page up']
      normal_like: ['ctrl+u']
      insert_like: ['ctrl+up']
  }

  CMD_SEARCH = keyDefinitions.registerCommand {
    name: 'SEARCH'
    default_hotkeys:
      normal_like: ['/', 'ctrl+f']
  }
  CMD_MARK = keyDefinitions.registerCommand {
    name: 'MARK'
    default_hotkeys:
      normal_like: ['m']
  }
  CMD_MARK_SEARCH = keyDefinitions.registerCommand {
    name: 'MARK_SEARCH'
    default_hotkeys:
      normal_like: ['\'', '`']
  }

  CMD_ENTER_VISUAL = keyDefinitions.registerCommand {
    name: 'ENTER_VISUAL'
    default_hotkeys:
      normal_like: ['v']
  }
  CMD_ENTER_VISUAL_LINE = keyDefinitions.registerCommand {
    name: 'ENTER_VISUAL_LINE'
    default_hotkeys:
      normal_like: ['V']
  }

  CMD_SWAP_CURSOR = keyDefinitions.registerCommand {
    name: 'SWAP_CURSOR'
    default_hotkeys:
      normal_like: ['o', 'O']
  }
  CMD_EXIT_MODE = keyDefinitions.registerCommand {
    name: 'EXIT_MODE'
    default_hotkeys:
      all: ['esc', 'ctrl+c']
  }

  # TODO: SWAP_CASE         : ['~']

  CMD_FINISH_MARK = keyDefinitions.registerCommand {
    name: 'FINISH_MARK'
    default_hotkeys:
      insert_like: ['enter']
  }

  ####################
  # easy motion
  ####################

  CMD_EASY_MOTION = keyDefinitions.registerCommand {
    name: 'EASY_MOTION'
    default_hotkeys:
      normal_like: ['space']
  }
  keyDefinitions.registerMotion CMD_EASY_MOTION, {
    description: 'Jump to a visible row (based on EasyMotion)',
  }, () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait

      rows = (do @view.getVisibleRows).filter (row) =>
               return not (row.is @view.cursor.row)
      keys = [
        'z', 'x', 'c', 'v',
        'q', 'w', 'e', 'r', 't',
        'a', 's', 'd', 'f',
        'g', 'h', 'j', 'k', 'l',
        'y', 'u', 'i', 'o', 'p',
        'b', 'n', 'm',
      ]

      if keys.length > rows.length
        start = (keys.length - rows.length) / 2
        keys = keys.slice(start, start + rows.length)
      else
        start = (rows.length - keys.length) / 2
        rows = rows.slice(start, start + rows.length)

      mappings = {
        key_to_row: {}
        row_to_key: {}
      }
      for [row, key] in _.zip(rows, keys)
        mappings.key_to_row[key] = row
        mappings.row_to_key[JSON.stringify do row.getAncestry] = key
      @view.easy_motion_mappings = mappings

      return null
    else
      return (cursor, options) ->
        if key of @view.easy_motion_mappings.key_to_row
          row = @view.easy_motion_mappings.key_to_row[key]
          cursor.set row, 0
        @view.easy_motion_mappings = null


  CMD_GO = keyDefinitions.registerCommand {
    name: 'GO'
    default_hotkeys:
      normal_like: ['g']
  }
  CMD_PARENT = keyDefinitions.registerCommand {
    name: 'PARENT'
    default_hotkeys:
      normal_like: ['p']
  }
  go_definition = {} # bindings for second key
  keyDefinitions.registerSubmotion go_definition, CMD_GO, {
    description: 'Go to the beginning of visible document',
  }, () ->
    return (cursor, options) ->
      cursor.visibleHome options
  keyDefinitions.registerSubmotion go_definition, CMD_PARENT, {
    description: 'Go to the parent of current line',
  }, () ->
    return (cursor, options) ->
      cursor.parent options
  keyDefinitions.registerSubmotion go_definition, CMD_MARK, {
    description: 'Go to the mark indicated by the cursor, if it exists',
  },  () ->
    return (cursor, options) ->
      do cursor.goMark
  keyDefinitions.registerMotion CMD_GO, {
    description: 'Various commands for navigation (operator)',
  }, go_definition

  ####################
  # ACTIONS
  ####################

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

  # TODO: THIS IS A HACK...
  CMD_MOTION = {name: 'MOTION'}

  keyDefinitions.registerAction [MODES.NORMAL], CMD_MOTION, {
    description: 'Move the cursor',
  }, (motion) ->
    for i in [1..@repeat]
      motion @view.cursor, {}
    do @keyStream.forget
  keyDefinitions.registerAction [MODES.INSERT], CMD_MOTION, {
    description: 'Move the cursor',
  }, (motion) ->
    motion @view.cursor, {pastEnd: true}
  keyDefinitions.registerAction [MODES.VISUAL], CMD_MOTION, {
    description: 'Move the cursor',
  }, (motion) ->
    # this is necessary until we figure out multiline
    tmp = do @view.cursor.clone
    for i in [1..@repeat]
      motion tmp, {pastEnd: true}

    if not (tmp.row.is @view.cursor.row) # only allow same-row movement
      @view.showMessage "Visual mode currently only works on one line", {text_class: 'error'}
    else
      @view.cursor.from tmp
  keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_MOTION, {
    description: 'Move the cursor',
  }, (motion) ->
    for i in [1..@repeat]
      motion @view.cursor, {pastEnd: true}
  keyDefinitions.registerAction [MODES.MARK], CMD_MOTION, {
    description: 'Move the cursor',
  }, (motion) ->
    motion @view.markview.cursor, {pastEnd: true}
  keyDefinitions.registerAction [MODES.SEARCH], CMD_MOTION, {
    description: 'Move the cursor',
  }, (motion) ->
    motion @view.menu.view.cursor, {pastEnd: true}

  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_TOGGLE_FOLD, {
    description: 'Toggle whether a block is folded',
  }, () ->
    do @view.toggleCurBlock
    if @mode == MODES.NORMAL
      do @keyStream.save

  # content-based navigation

  keyDefinitions.registerAction [MODES.NORMAL], CMD_SEARCH, {
    description: 'Search',
  }, () ->
    @view.setMode MODES.SEARCH
    @view.menu = new Menu @view.menuDiv, (chars) =>
      find = (data, query, options = {}) ->
        nresults = options.nresults or 10
        case_sensitive = options.case_sensitive

        results = [] # list of (row_id, index) pairs

        canonicalize = (x) ->
          return if options.case_sensitive then x else x.toLowerCase()

        get_words = (char_array) ->
          return (char_array.join '')
            .split(/\s/g)
            .filter((x) -> x.length)
            .map canonicalize

        query_words = get_words query
        if query.length == 0
          return results

        for row in do data.orderedLines
          line = canonicalize (data.getText row).join ''
          matches = []
          if _.all(query_words.map ((word) ->
                    i = line.indexOf word
                    if i == -1 then return false
                    matches = matches.concat [i...i+word.length]
                    return true
                  ))
            results.push { row: row, matches: matches }
          if nresults > 0 and results.length == nresults
            break
        return results

      return _.map(
        (find @view.data, chars),
        (found) =>
          row = found.row
          highlights = {}
          for i in found.matches
            highlights[i] = true
          return {
            contents: @view.data.getLine row
            renderOptions: { highlights: highlights }
            fn: () => @view.rootInto row
          }
      )

  keyDefinitions.registerAction [MODES.NORMAL], CMD_MARK, {
    description: 'Mark a line',
  }, () ->
    @view.setMode MODES.MARK
  keyDefinitions.registerAction [MODES.MARK], CMD_FINISH_MARK, {
    description: 'Finish typing mark',
  }, () ->
    mark = (do @view.markview.curText).join ''
    @view.setMark @view.markrow, mark
    @view.setMode MODES.NORMAL
    do @keyStream.save
  keyDefinitions.registerAction [MODES.NORMAL], CMD_MARK_SEARCH, {
    description: 'Go to (search for) a mark',
  }, () ->
    @view.setMode MODES.SEARCH
    @view.menu = new Menu @view.menuDiv, (chars) =>
      # find marks that start with the prefix
      findMarks = (data, prefix, nresults = 10) ->
        results = [] # list of rows
        for mark, row of (do data.getAllMarks)
          if (mark.indexOf prefix) == 0
            results.push { row: row, mark: mark }
            if nresults > 0 and results.length == nresults
              break
        return results

      text = chars.join('')
      return _.map(
        (findMarks @view.data, text),
        (found) =>
          row = found.row
          return {
            contents: @view.data.getLine row
            renderOptions: { mark: found.mark }
            fn: () => @view.rootInto row
          }
      )

  # TODO: visual and visual_line mode
  keyDefinitions.registerAction [MODES.NORMAL], CMD_REPLACE, {
    description: 'Replace character',
  }, () ->
    key = do @keyStream.dequeue
    if key == null then return do @keyStream.wait
    @view.replaceCharsAfterCursor key, @repeat, {setCursor: 'end'}
    do @keyStream.save


  keyDefinitions.registerAction [MODES.VISUAL], CMD_DELETE, {
    description: 'Delete',
  }, (do visual_mode_delete_fn)
  keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_DELETE, {
    description: 'Delete',
  }, (do visual_line_mode_delete_fn)

  delete_definition = {}
  keyDefinitions.registerSubaction delete_definition, CMD_DELETE, {
    description: 'Delete blocks'
  }, () ->
    @view.delBlocksAtCursor @repeat, {addNew: false}
    do @keyStream.save
  keyDefinitions.registerSubaction delete_definition, CMD_MOTION, {
    description: 'Delete from cursor with motion'
  }, (motion) ->
    cursor = do @view.cursor.clone
    for i in [1..@repeat]
      motion cursor, {pastEnd: true, pastEndWord: true}

    @view.deleteBetween @view.cursor, cursor, { yank: true }
    do @keyStream.save
  keyDefinitions.registerSubaction delete_definition, CMD_MARK, {
    description: 'Delete mark at cursor'
  }, () ->
    @view.setMark @view.cursor.row, ''
    do @keyStream.save

  keyDefinitions.registerAction [MODES.NORMAL], CMD_DELETE, {
    description: 'Delete (operator)',
  }, delete_definition

  keyDefinitions.registerAction [MODES.VISUAL], CMD_CHANGE, {
    description: 'Change',
  }, () ->
    options = {includeEnd: true, yank: true, cursor: {pastEnd: true}}
    @view.deleteBetween @view.cursor, @view.anchor, options
    @view.setMode MODES.INSERT
  keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_CHANGE, {
    description: 'Change',
  }, () ->
    @view.delBlocks @parent, @row_start_i, @num_rows, {addNew: true}
    @view.setMode MODES.INSERT
  change_definition = {}
  keyDefinitions.registerSubaction change_definition, CMD_CHANGE, {
    description: 'Delete blocks, and enter insert mode'
  }, () ->
    @view.setMode MODES.INSERT
    @view.delBlocksAtCursor @repeat, {addNew: true}
  keyDefinitions.registerSubaction change_definition, CMD_MOTION, {
    description: 'Delete from cursor with motion, and enter insert mode'
  }, (motion) ->
    cursor = do @view.cursor.clone
    for i in [1..@repeat]
      motion cursor, {pastEnd: true, pastEndWord: true}
    @view.setMode MODES.INSERT
    @view.deleteBetween @view.cursor, cursor, {yank: true, cursor: { pastEnd: true }}
  keyDefinitions.registerAction [MODES.NORMAL], CMD_CHANGE, {
    description: 'Change (operator)',
  }, change_definition

  keyDefinitions.registerAction [MODES.VISUAL], CMD_YANK, {
    description: 'Yank',
  }, () ->
    options = {includeEnd: true}
    @view.yankBetween @view.cursor, @view.anchor, options
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_YANK, {
    description: 'Yank',
  }, () ->
    @view.yankBlocks @row_start, @num_rows
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  yank_definition = {}
  keyDefinitions.registerSubaction yank_definition, CMD_YANK, {
    description: 'Yank blocks'
  }, () ->
    @view.yankBlocksAtCursor @repeat
    do @keyStream.forget
  keyDefinitions.registerSubaction yank_definition, CMD_MOTION, {
    description: 'Yank from cursor with motion'
  }, (motion) ->
    cursor = do @view.cursor.clone
    for i in [1..@repeat]
      motion cursor, {pastEnd: true, pastEndWord: true}

    @view.yankBetween @view.cursor, cursor, {}
    do @keyStream.forget
  keyDefinitions.registerSubaction yank_definition, CMD_CLONE, {
    description: 'Yank blocks as a clone'
  }, () ->
    @view.yankBlocksCloneAtCursor @repeat
    do @keyStream.forget
  keyDefinitions.registerAction [MODES.NORMAL], CMD_YANK, {
    description: 'Yank (operator)',
  }, yank_definition

  #   jeff: c conflicts with change, so this doesn't work
  # keyDefinitions.registerAction [MODES.VISUAL_LINE],  CMD_CLONE, {
  #   description: 'Yank blocks as a clone',
  # }, () ->
  #   @view.yankBlocksClone @row_start, @num_rows
  #   @view.setMode MODES.NORMAL
  #   do @keyStream.forget

  keyDefinitions.registerAction [MODES.NORMAL], CMD_DELETE_CHAR, {
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.delCharsAfterCursor @repeat, {yank: true}
    do @keyStream.save
  # behaves like row delete, in visual line
  keyDefinitions.registerAction [MODES.VISUAL], CMD_DELETE_CHAR, {
    description: 'Delete character at the cursor (i.e. del key)',
  }, (do visual_mode_delete_fn)
  keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_DELETE_CHAR, {
    description: 'Delete character at the cursor (i.e. del key)',
  }, (do visual_line_mode_delete_fn)
  keyDefinitions.registerAction [MODES.INSERT], CMD_DELETE_CHAR, {
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.delCharsAfterCursor 1
  keyDefinitions.registerAction [MODES.MARK], CMD_DELETE_CHAR, {
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.markview.delCharsAfterCursor 1
  keyDefinitions.registerAction [MODES.SEARCH], CMD_DELETE_CHAR, {
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.menu.view.delCharsAfterCursor 1

  keyDefinitions.registerAction [MODES.NORMAL], CMD_DELETE_LAST_CHAR, {
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    num = Math.min @view.cursor.col, @repeat
    if num > 0
      @view.delCharsBeforeCursor num, {yank: true}
    do @keyStream.save
  # behaves like row delete, in visual line
  keyDefinitions.registerAction [MODES.VISUAL], CMD_DELETE_LAST_CHAR, {
    description: 'Delete last character (i.e. backspace key)',
  }, (do visual_mode_delete_fn)
  keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_DELETE_LAST_CHAR, {
    description: 'Delete last character (i.e. backspace key)',
  }, (do visual_line_mode_delete_fn)
  keyDefinitions.registerAction [MODES.INSERT], CMD_DELETE_LAST_CHAR, {
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    do @view.deleteAtCursor
  keyDefinitions.registerAction [MODES.MARK], CMD_DELETE_LAST_CHAR, {
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    do @view.markview.deleteAtCursor
  keyDefinitions.registerAction [MODES.SEARCH], CMD_DELETE_LAST_CHAR, {
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    do @view.menu.view.deleteAtCursor

  keyDefinitions.registerAction [MODES.NORMAL], CMD_CHANGE_CHAR, {
    description: 'Change character',
  }, () ->
    @view.delCharsAfterCursor 1, {cursor: {pastEnd: true}}, {yank: true}
    @view.setMode MODES.INSERT

  # TODO: something like this would be nice...
  # keyDefinitions.registerActionAsMacro CMD_DELETE_TO_HOME, [CMD_DELETE, CMD_HOME]
  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_DELETE_TO_HOME, {
    description: 'Delete to the beginning of the line',
  }, () ->
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
  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_DELETE_TO_END, {
    description: 'Delete to the end of the line',
  }, () ->
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
  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_DELETE_LAST_WORD, {
    description: 'Delete to the beginning of the previous word',
  }, () ->
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

  keyDefinitions.registerAction [MODES.NORMAL], CMD_PASTE_AFTER, {
    description: 'Paste after cursor',
  }, () ->
    do @view.pasteAfter
    do @keyStream.save
  # NOTE: paste after doesn't make sense for insert mode
  keyDefinitions.registerAction [MODES.NORMAL], CMD_PASTE_BEFORE, {
    description: 'Paste before cursor',
  }, () ->
    @view.pasteBefore {}
    do @keyStream.save
  keyDefinitions.registerAction [MODES.INSERT], CMD_PASTE_BEFORE, {
    description: 'Paste before cursor',
  }, () ->
    @view.pasteBefore {cursor: {pastEnd: true}}

  keyDefinitions.registerAction [MODES.NORMAL], CMD_JOIN_LINE, {
    description: 'Join current line with line below',
  }, () ->
    do @view.joinAtCursor
    do @keyStream.save
  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_SPLIT_LINE, {
    description: 'Split line at cursor (i.e. enter key)',
  }, () ->
    do @view.newLineAtCursor
    if @mode == MODES.NORMAL
      do @keyStream.save

  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_SCROLL_DOWN, {
    description: 'Scroll half window down',
  }, () ->
    @view.scrollPages 0.5
    @keyStream.forget 1

  keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_SCROLL_UP, {
    description: 'Scroll half window up',
  }, () ->
    @view.scrollPages -0.5
    @keyStream.forget 1

  # for everything but normal mode
  keyDefinitions.registerAction [MODES.VISUAL, MODES.VISUAL_LINE, MODES.SEARCH, MODES.MARK], CMD_EXIT_MODE, {
    description: 'Exit back to normal mode',
  }, () ->
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  keyDefinitions.registerAction [MODES.INSERT], CMD_EXIT_MODE, {
    description: 'Exit back to normal mode',
  }, () ->
    do @view.cursor.left
    @view.setMode MODES.NORMAL
    # unlike other modes, esc in insert mode keeps changes
    do @keyStream.save

  # for visual and visual line mode
  keyDefinitions.registerAction [MODES.NORMAL], CMD_ENTER_VISUAL, {
    description: 'Enter visual mode',
  }, () ->
    @view.setMode MODES.VISUAL
  keyDefinitions.registerAction [MODES.NORMAL], CMD_ENTER_VISUAL_LINE, {
    description: 'Enter visual line mode',
  }, () ->
    @view.setMode MODES.VISUAL_LINE
  keyDefinitions.registerAction [MODES.VISUAL, MODES.VISUAL_LINE], CMD_SWAP_CURSOR, {
    description: 'Swap cursor to other end of selection, in visual and visual line mode',
  }, () ->
    tmp = do @view.anchor.clone
    @view.anchor.from @view.cursor
    @view.cursor.from tmp
    do @keyStream.save

)()
