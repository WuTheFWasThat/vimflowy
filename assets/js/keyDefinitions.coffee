if module?
  global.tv4 = require('tv4')

  global.errors = require('./errors.coffee')
  global.Modes = require('./modes.coffee')

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
  MODES = Modes.modes

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
  # the motion itself should take a cursor, and an options dictionary
  # (it should presumably move the cursor, somehow)
  # options include:
  #     pastEnd: whether to allow going past the end of the line
  #     pastEndWord: whether we consider the end of a word to be after the last letter

  MOTION_SCHEMA = {
    title: "Motion metadata schema"
    type: "object"
    required: [ 'name', 'description' ]
    properties: {
      name: {
        description: "Name of the motion"
        type: "string"
      }
      description: {
        description: "Description of the motion"
        type: "string"
      }
    }
  }

  motionDefinitions = {}

  registerSubmotion = (
    mainDefinition,
    motion,
    definition
  ) ->
    if not tv4.validate(motion, MOTION_SCHEMA, true, true)
      throw new errors.GenericError(
        "Error validating motion #{JSON.stringify(motion, null, 2)}: #{JSON.stringify(tv4.error)}"
      )
    motion.definition = definition
    mainDefinition[motion.name] = motion

  registerMotion = registerSubmotion.bind @, motionDefinitions

  registerMotion {
    name: 'LEFT',
    description: 'Move cursor left',
  }, () ->
    return (cursor, options) ->
      cursor.left options

  registerMotion {
    name: 'RIGHT',
    description: 'Move cursor right',
  }, () ->
    return (cursor, options) ->
      cursor.right options

  registerMotion {
    name: 'UP',
    description: 'Move cursor up',
  }, () ->
    return (cursor, options) ->
      cursor.up options

  registerMotion {
    name: 'DOWN',
    description: 'Move cursor down',
  }, () ->
    return (cursor, options) ->
      cursor.down options

  registerMotion {
    name: 'HOME',
    description: 'Move cursor to beginning of line',
  }, () ->
    return (cursor, options) ->
      cursor.home options

  registerMotion {
    name: 'END',
    description: 'Move cursor to end of line',
  }, () ->
    return (cursor, options) ->
      cursor.end options

  registerMotion {
    name: 'BEGINNING_WORD',
    description: 'Move cursor to the first word-beginning before it',
  }, () ->
    return (cursor, options) ->
      cursor.beginningWord {cursor: options}

  registerMotion {
    name: 'END_WORD',
    description: 'Move cursor to the first word-ending after it',
  }, () ->
    return (cursor, options) ->
      cursor.endWord {cursor: options}

  registerMotion {
    name: 'NEXT_WORD',
    description: 'Move cursor to the beginning of the next word',
  }, () ->
    return (cursor, options) ->
      cursor.nextWord {cursor: options}

  registerMotion {
    name: 'BEGINNING_WWORD',
    description: 'Move cursor to the first Word-beginning before it',
  }, () ->
    return (cursor, options) ->
      cursor.beginningWord {cursor: options, whitespaceWord: true}

  registerMotion {
    name: 'END_WWORD',
    description: 'Move cursor to the first Word-ending after it',
  }, () ->
    return (cursor, options) ->
      cursor.endWord {cursor: options, whitespaceWord: true}

  registerMotion {
    name: 'NEXT_WWORD',
    description: 'Move cursor to the beginning of the next Word',
  }, () ->
    return (cursor, options) ->
      cursor.nextWord {cursor: options, whitespaceWord: true}

  registerMotion {
    name: 'FIND_NEXT_CHAR',
    description: 'Move cursor to next occurrence of character in line',
  }, () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findNextChar key, {cursor: options}

  registerMotion {
    name: 'FIND_PREV_CHAR',
    description: 'Move cursor to previous occurrence of character in line',
  }, () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findPrevChar key, {cursor: options}

  registerMotion {
    name: 'TO_NEXT_CHAR',
    description: 'Move cursor to just before next occurrence of character in line',
  }, () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findNextChar key, {cursor: options, beforeFound: true}

  registerMotion {
    name: 'TO_PREV_CHAR',
    description: 'Move cursor to just after previous occurrence of character in line',
  }, () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait
      return null
    return (cursor, options) ->
      cursor.findPrevChar key, {cursor: options, beforeFound: true}

  registerMotion {
    name: 'NEXT_SIBLING',
    description: 'Move cursor to the next sibling of the current line',
  }, () ->
    return (cursor, options) ->
      cursor.nextSibling options

  registerMotion {
    name: 'PREV_SIBLING',
    description: 'Move cursor to the previous sibling of the current line',
  }, () ->
    return (cursor, options) ->
      cursor.prevSibling options

  registerMotion {
    name: 'GO_END',
    description: 'Go to end of visible document',
  }, () ->
    return (cursor, options) ->
      cursor.visibleEnd options

  registerMotion {
    name: 'EASY_MOTION',
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

  go_definition = {} # bindings for second key
  registerSubmotion go_definition, {
    name: 'GO',
    description: 'Go to the beginning of visible document',
  }, () ->
    return (cursor, options) ->
      cursor.visibleHome options
  registerSubmotion go_definition, {
    name: 'PARENT',
    description: 'Go to the parent of current line',
  }, () ->
    return (cursor, options) ->
      cursor.parent options
  registerSubmotion go_definition, {
    name: 'MARK',
    description: 'Go to the mark indicated by the cursor, if it exists',
  },  () ->
    return (cursor, options) ->
      do cursor.goMark
  registerMotion {
    name: 'GO',
    description: 'Various commands for navigation (operator)',
  }, go_definition

  ACTION_SCHEMA = {
    title: "Action metadata schema"
    type: "object"
    required: [ 'name', 'description' ]
    properties: {
      name: {
        description: "Name of the action"
        type: "string"
      }
      description: {
        description: "Description of the action"
        type: "string"
      }
    }
  }

  actionDefinitions = {}

  registerSubaction = (
    mainDefinition,
    modes,
    action,
    definition
  ) ->
    if not tv4.validate(action, ACTION_SCHEMA, true, true)
      throw new errors.GenericError(
        "Error validating action #{JSON.stringify(action, null, 2)}: #{JSON.stringify(tv4.error)}"
      )
    for mode in modes
      if not (mode of mainDefinition)
        mainDefinition[mode] = {}
      mainDefinition[mode][action.name] = _.cloneDeep action
      mainDefinition[mode][action.name].definition = definition

  registerAction = registerSubaction.bind @, actionDefinitions

  registerAction [MODES.NORMAL], {
    name: 'MOTION',
    description: 'Move the cursor',
  }, (motion) ->
    for i in [1..@repeat]
      motion @view.cursor, {}
    do @keyStream.forget
  registerAction [MODES.INSERT], {
    name: 'MOTION',
    description: 'Move the cursor',
  }, (motion) ->
    motion @view.cursor, {pastEnd: true}
  registerAction [MODES.VISUAL], {
    name: 'MOTION',
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
  registerAction [MODES.VISUAL_LINE], {
    name: 'MOTION',
    description: 'Move the cursor',
  }, (motion) ->
    for i in [1..@repeat]
      motion @view.cursor, {pastEnd: true}
  registerAction [MODES.MARK], {
    name: 'MOTION',
    description: 'Move the cursor',
  }, (motion) ->
    motion @view.markview.cursor, {pastEnd: true}
  registerAction [MODES.SEARCH], {
    name: 'MOTION',
    description: 'Move the cursor',
  }, (motion) ->
    motion @view.menu.view.cursor, {pastEnd: true}

  registerAction [MODES.NORMAL], {
    name: 'HELP',
    description: 'Show/hide key bindings (edit in settings)',
  }, () ->
    do @view.toggleBindingsDiv
    do @keyStream.forget

  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'ZOOM_IN',
    description: 'Zoom in by one level',
  }, () ->
    do @view.rootDown
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'ZOOM_OUT',
    description: 'Zoom out by one level',
  }, () ->
    do @view.rootUp
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'ZOOM_IN_ALL',
    description: 'Zoom in onto cursor',
  }, () ->
    do @view.rootInto
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'ZOOM_OUT_ALL',
    description: 'Zoom out to home',
  }, () ->
    do @view.reroot
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction [MODES.NORMAL], {
    name: 'INDENT_RIGHT',
    description: 'Indent row right',
  }, () ->
    do @view.indent
    do @keyStream.save
  registerAction [MODES.INSERT], {
    name: 'INDENT_RIGHT',
    description: 'Indent row right',
  }, () ->
    do @view.indent
  # NOTE: this matches block indent behavior, in visual line
  registerAction [MODES.VISUAL_LINE], {
    name: 'INDENT_RIGHT',
    description: 'Indent row right',
  }, (do visual_line_indent)
  registerAction [MODES.NORMAL], {
    name: 'INDENT_LEFT',
    description: 'Indent row left',
  }, () ->
    do @view.unindent
    do @keyStream.save
  registerAction [MODES.INSERT], {
    name: 'INDENT_LEFT',
    description: 'Indent row left',
  }, () ->
    do @view.unindent
  # NOTE: this matches block indent behavior, in visual line
  registerAction [MODES.VISUAL_LINE], {
    name: 'INDENT_LEFT',
    description: 'Indent row left',
  }, (do visual_line_unindent)

  registerAction [MODES.NORMAL], {
    name: 'MOVE_BLOCK_RIGHT',
    description: 'Move block right',
  }, () ->
    @view.indentBlocks @view.cursor.row, @repeat
    do @keyStream.save
  registerAction [MODES.INSERT], {
    name: 'MOVE_BLOCK_RIGHT',
    description: 'Move block right',
  }, () ->
    @view.indentBlocks @view.cursor.row, 1
  registerAction [MODES.VISUAL_LINE], {
    name: 'MOVE_BLOCK_RIGHT',
    description: 'Move block right',
  }, (do visual_line_indent)
  registerAction [MODES.NORMAL], {
    name: 'MOVE_BLOCK_LEFT',
    description: 'Move block left',
  }, () ->
    @view.unindentBlocks @view.cursor.row, @repeat
    do @keyStream.save
  registerAction [MODES.INSERT], {
    name: 'MOVE_BLOCK_LEFT',
    description: 'Move block left',
  }, () ->
    @view.unindentBlocks @view.cursor.row, 1
  registerAction [MODES.VISUAL_LINE], {
    name: 'MOVE_BLOCK_LEFT',
    description: 'Move block left',
  }, (do visual_line_unindent)
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'MOVE_BLOCK_DOWN',
    description: 'Move block down',
  }, () ->
    do @view.swapDown
    if @mode == MODES.NORMAL
      do @keyStream.save
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'MOVE_BLOCK_UP',
    description: 'Move block up',
  }, () ->
    do @view.swapUp
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'TOGGLE_FOLD',
    description: 'Toggle whether a block is folded',
  }, () ->
    do @view.toggleCurBlock
    if @mode == MODES.NORMAL
      do @keyStream.save

  # content-based navigation

  registerAction [MODES.NORMAL], {
    name: 'SEARCH',
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

  registerAction [MODES.NORMAL], {
    name: 'MARK',
    description: 'Mark a line',
  }, () ->
    @view.setMode MODES.MARK
    do @keyStream.forget
  registerAction [MODES.MARK], {
    name: 'FINISH_MARK',
    description: 'Finish typing mark',
  }, () ->
    mark = (do @view.markview.curText).join ''
    @view.setMark @view.markrow, mark
    @view.setMode MODES.NORMAL
    do @keyStream.save
  registerAction [MODES.NORMAL], {
    name: 'MARK_SEARCH',
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

  registerAction [MODES.NORMAL], {
    name: 'JUMP_PREVIOUS',
    description: 'Jump to previous location',
  }, () ->
    do @view.jumpPrevious
    do @keyStream.forget
  registerAction [MODES.NORMAL], {
    name: 'JUMP_NEXT',
    description: 'Jump to next location',
  }, () ->
    do @view.jumpNext
    do @keyStream.forget

  # traditional vim stuff
  registerAction [MODES.NORMAL], {
    name: 'INSERT',
    description: 'Insert at character',
  }, () ->
    @view.setMode MODES.INSERT
  registerAction [MODES.NORMAL], {
    name: 'INSERT_AFTER',
    description: 'Insert after character',
  }, () ->
    @view.setMode MODES.INSERT
    @view.cursor.right {pastEnd: true}
  registerAction [MODES.NORMAL], {
    name: 'INSERT_HOME',
    description: 'Insert at beginning of line',
  }, () ->
    @view.setMode MODES.INSERT
    do @view.cursor.home
  registerAction [MODES.NORMAL], {
    name: 'INSERT_END',
    description: 'Insert after end of line',
  }, () ->
    @view.setMode MODES.INSERT
    @view.cursor.end {pastEnd: true}
  registerAction [MODES.NORMAL], {
    name: 'INSERT_LINE_BELOW',
    description: 'Insert on new line after current line',
  }, () ->
    @view.setMode MODES.INSERT
    do @view.newLineBelow
  registerAction [MODES.NORMAL], {
    name: 'INSERT_LINE_ABOVE',
    description: 'Insert on new line before current line',
  }, () ->
    @view.setMode MODES.INSERT
    do @view.newLineAbove

  # TODO: visual and visual_line mode
  registerAction [MODES.NORMAL], {
    name: 'REPLACE',
    description: 'Replace character',
  }, () ->
    key = do @keyStream.dequeue
    if key == null then return do @keyStream.wait
    @view.replaceCharsAfterCursor key, @repeat, {setCursor: 'end'}
    do @keyStream.save

  registerAction [MODES.NORMAL], {
    name: 'UNDO',
    description: 'Undo',
  }, () ->
    for i in [1..@repeat]
      do @view.undo
    do @keyStream.forget
  registerAction [MODES.NORMAL], {
    name: 'REDO',
    description: 'Redo',
  }, () ->
    for i in [1..@repeat]
      do @view.redo
    do @keyStream.forget
  registerAction [MODES.NORMAL], {
    name: 'REPLAY',
    description: 'Replay last command',
  }, () ->
    for i in [1..@repeat]
      @keyHandler.playRecording @keyStream.lastSequence
      do @view.save
    do @keyStream.forget
  registerAction [MODES.NORMAL], {
    name: 'RECORD_MACRO',
    description: 'Begin/stop recording a macro',
  }, () ->
    if @keyHandler.recording.stream == null
      key = do @keyStream.dequeue
      if key == null then return do @keyStream.wait
      @keyHandler.beginRecording key
    else
      # pop off the RECORD_MACRO itself
      do @keyHandler.recording.stream.queue.pop
      do @keyHandler.finishRecording
    do @keyStream.forget
  registerAction [MODES.NORMAL], {
    name: 'PLAY_MACRO',
    description: 'Play a macro',
  }, () ->
    key = do @keyStream.dequeue
    if key == null then return do @keyStream.wait
    recording = @keyHandler.macros[key]
    if recording == undefined then return do @keyStream.forget
    for i in [1..@repeat]
      @keyHandler.playRecording recording
    # save the macro-playing sequence itself
    do @keyStream.save

  registerAction [MODES.VISUAL], {
    name: 'DELETE',
    description: 'Delete',
  }, (do visual_mode_delete_fn)
  registerAction [MODES.VISUAL_LINE], {
    name: 'DELETE',
    description: 'Delete',
  }, (do visual_line_mode_delete_fn)
  registerAction [MODES.NORMAL], {
    name: 'DELETE',
    description: 'Delete (operator)',
  }, {
    DELETE:
      description: 'Delete blocks'
      definition: () ->
        @view.delBlocksAtCursor @repeat, {addNew: false}
        do @keyStream.save
    MOTION:
      description: 'Delete from cursor with motion'
      definition: (motion) ->
        cursor = do @view.cursor.clone
        for i in [1..@repeat]
          motion cursor, {pastEnd: true, pastEndWord: true}

        @view.deleteBetween @view.cursor, cursor, { yank: true }
        do @keyStream.save
    MARK:
      description: 'Delete mark at cursor'
      definition: () ->
        @view.setMark @view.cursor.row, ''
        do @keyStream.save
  }

  registerAction [MODES.VISUAL], {
    name: 'CHANGE',
    description: 'Change',
  }, () ->
    options = {includeEnd: true, yank: true, cursor: {pastEnd: true}}
    @view.deleteBetween @view.cursor, @view.anchor, options
    @view.setMode MODES.INSERT
  registerAction [MODES.VISUAL_LINE], {
    name: 'CHANGE',
    description: 'Change',
  }, () ->
    @view.delBlocks @parent, @row_start_i, @num_rows, {addNew: true}
    @view.setMode MODES.INSERT
  registerAction [MODES.NORMAL], {
    name: 'CHANGE',
    description: 'Change (operator)',
  }, {
    CHANGE:
      description: 'Delete blocks, and enter insert mode'
      definition: () ->
        @view.setMode MODES.INSERT
        @view.delBlocksAtCursor @repeat, {addNew: true}
    MOTION:
      description: 'Delete from cursor with motion, and enter insert mode'
      definition: (motion) ->
        cursor = do @view.cursor.clone
        for i in [1..@repeat]
          motion cursor, {pastEnd: true, pastEndWord: true}

        @view.setMode MODES.INSERT
        @view.deleteBetween @view.cursor, cursor, {yank: true, cursor: { pastEnd: true }}
  }

  registerAction [MODES.VISUAL], {
    name: 'YANK',
    description: 'Yank',
  }, () ->
    options = {includeEnd: true}
    @view.yankBetween @view.cursor, @view.anchor, options
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  registerAction [MODES.VISUAL_LINE], {
    name: 'YANK',
    description: 'Yank',
  }, () ->
    @view.yankBlocks @row_start, @num_rows
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  registerAction [MODES.NORMAL], {
    name: 'YANK',
    description: 'Yank (operator)',
  }, {
    YANK:
      description: 'Yank blocks'
      definition: () ->
        @view.yankBlocksAtCursor @repeat
        do @keyStream.forget
    MOTION:
      description: 'Yank from cursor with motion'
      definition: (motion) ->
        cursor = do @view.cursor.clone
        for i in [1..@repeat]
          motion cursor, {pastEnd: true, pastEndWord: true}

        @view.yankBetween @view.cursor, cursor, {}
        do @keyStream.forget
    CLONE:
      display: 'Yank blocks as a clone'
      definition: () ->
        @view.yankBlocksCloneAtCursor @repeat
        do @keyStream.forget
  }

  #   jeff: c conflicts with change, so this doesn't work
  # registerAction [MODES.VISUAL_LINE], {
  #   name: 'CLONE',
  #   description: 'Yank blocks as a clone',
  # }, () ->
  #   @view.yankBlocksClone @row_start, @num_rows
  #   @view.setMode MODES.NORMAL
  #   do @keyStream.forget

  registerAction [MODES.NORMAL], {
    name: 'DELETE_CHAR',
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.delCharsAfterCursor @repeat, {yank: true}
    do @keyStream.save
  # behaves like row delete, in visual line
  registerAction [MODES.VISUAL], {
    name: 'DELETE_CHAR',
    description: 'Delete character at the cursor (i.e. del key)',
  }, (do visual_mode_delete_fn)
  registerAction [MODES.VISUAL_LINE], {
    name: 'DELETE_CHAR',
    description: 'Delete character at the cursor (i.e. del key)',
  }, (do visual_line_mode_delete_fn)
  registerAction [MODES.INSERT], {
    name: 'DELETE_CHAR',
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.delCharsAfterCursor 1
  registerAction [MODES.MARK], {
    name: 'DELETE_CHAR',
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.markview.delCharsAfterCursor 1
  registerAction [MODES.SEARCH], {
    name: 'DELETE_CHAR',
    description: 'Delete character at the cursor (i.e. del key)',
  }, () ->
    @view.menu.view.delCharsAfterCursor 1

  registerAction [MODES.NORMAL], {
    name: 'DELETE_LAST_CHAR',
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    num = Math.min @view.cursor.col, @repeat
    if num > 0
      @view.delCharsBeforeCursor num, {yank: true}
    do @keyStream.save
  # behaves like row delete, in visual line
  registerAction [MODES.VISUAL], {
    name: 'DELETE_LAST_CHAR',
    description: 'Delete last character (i.e. backspace key)',
  }, (do visual_mode_delete_fn)
  registerAction [MODES.VISUAL_LINE], {
    name: 'DELETE_LAST_CHAR',
    description: 'Delete last character (i.e. backspace key)',
  }, (do visual_line_mode_delete_fn)
  registerAction [MODES.INSERT], {
    name: 'DELETE_LAST_CHAR',
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    do @view.deleteAtCursor
  registerAction [MODES.MARK], {
    name: 'DELETE_LAST_CHAR',
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    do @view.markview.deleteAtCursor
  registerAction [MODES.SEARCH], {
    name: 'DELETE_LAST_CHAR',
    description: 'Delete last character (i.e. backspace key)',
  }, () ->
    do @view.menu.view.deleteAtCursor

  registerAction [MODES.NORMAL], {
    name: 'CHANGE_CHAR',
    description: 'Change character',
  }, () ->
    @view.delCharsAfterCursor 1, {cursor: {pastEnd: true}}, {yank: true}
    @view.setMode MODES.INSERT

  # TODO: something like this would be nice...
  # registerActionAsMacro 'DELETE_TO_HOME', ['DELETE', 'HOME']
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'DELETE_TO_HOME',
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
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'DELETE_TO_END',
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
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'DELETE_LAST_WORD',
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

  registerAction [MODES.NORMAL], {
    name: 'PASTE_AFTER',
    description: 'Paste after cursor',
  }, () ->
    do @view.pasteAfter
    do @keyStream.save
  # NOTE: paste after doesn't make sense for insert mode
  registerAction [MODES.NORMAL], {
    name: 'PASTE_BEFORE',
    description: 'Paste before cursor',
  }, () ->
    @view.pasteBefore {}
    do @keyStream.save
  registerAction [MODES.INSERT], {
    name: 'PASTE_BEFORE',
    description: 'Paste before cursor',
  }, () ->
    @view.pasteBefore {cursor: {pastEnd: true}}

  registerAction [MODES.NORMAL], {
    name: 'JOIN_LINE',
    description: 'Join current line with line below',
  }, () ->
    do @view.joinAtCursor
    do @keyStream.save
  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'SPLIT_LINE',
    description: 'Split line at cursor (i.e. enter key)',
  }, () ->
    do @view.newLineAtCursor
    if @mode == MODES.NORMAL
      do @keyStream.save

  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'SCROLL_DOWN',
    description: 'Scroll half window down',
  }, () ->
    @view.scrollPages 0.5
    if @mode == MODES.NORMAL
      do @keyStream.forget
    # TODO: if insert, forget *only this*

  registerAction [MODES.NORMAL, MODES.INSERT], {
    name: 'SCROLL_UP',
    description: 'Scroll half window up',
  }, () ->
    @view.scrollPages -0.5
    if @mode == MODES.NORMAL
      do @keyStream.forget

  # for everything but normal mode
  registerAction [MODES.VISUAL, MODES.VISUAL_LINE, MODES.SEARCH, MODES.MARK], {
    name: 'EXIT_MODE',
    description: 'Exit back to normal mode',
  }, () ->
    @view.setMode MODES.NORMAL
    do @keyStream.forget
  registerAction [MODES.INSERT], {
    name: 'EXIT_MODE',
    description: 'Exit back to normal mode',
  }, () ->
    do @view.cursor.left
    @view.setMode MODES.NORMAL
    # unlike other modes, esc in insert mode keeps changes
    do @keyStream.save

  # for visual and visual line mode
  registerAction [MODES.NORMAL], {
    name: 'ENTER_VISUAL',
    description: 'Enter visual mode',
  }, () ->
    @view.setMode MODES.VISUAL
  registerAction [MODES.NORMAL], {
    name: 'ENTER_VISUAL_LINE',
    description: 'Enter visual line mode',
  }, () ->
    @view.setMode MODES.VISUAL_LINE
  registerAction [MODES.VISUAL, MODES.VISUAL_LINE], {
    name: 'SWAP_CURSOR',
    description: 'Swap cursor to other end of selection, in visual and visual line mode',
  }, () ->
    tmp = do @view.anchor.clone
    @view.anchor.from @view.cursor
    @view.cursor.from tmp
    do @keyStream.save

  # for menu mode

  registerAction [MODES.SEARCH], {
    name: 'MENU_SELECT',
    description: 'Select current menu selection',
  }, () ->
    do @view.menu.select
    @view.setMode MODES.NORMAL
  registerAction [MODES.SEARCH], {
    name: 'MENU_UP',
    description: 'Select previous menu selection',
  }, () ->
    do @view.menu.up
  registerAction [MODES.SEARCH], {
    name: 'MENU_DOWN',
    description: 'Select next menu selection',
  }, () ->
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

  registerAction [MODES.NORMAL], {
    name: 'BOLD',
    description: 'Bold text',
  }, (text_format_normal 'bold')
  registerAction [MODES.INSERT], {
    name: 'BOLD',
    description: 'Bold text',
  }, (text_format_insert 'bold')
  registerAction [MODES.VISUAL], {
    name: 'BOLD',
    description: 'Bold text',
  }, (text_format_visual 'bold')
  registerAction [MODES.VISUAL_LINE], {
    name: 'BOLD',
    description: 'Bold text',
  }, (text_format_visual_line 'bold')
  registerAction [MODES.NORMAL], {
    name: 'ITALIC',
    description: 'Italicize text',
  }, (text_format_normal 'italic')
  registerAction [MODES.INSERT], {
    name: 'ITALIC',
    description: 'Italicize text',
  }, (text_format_insert 'italic')
  registerAction [MODES.VISUAL], {
    name: 'ITALIC',
    description: 'Italicize text',
  }, (text_format_visual 'italic')
  registerAction [MODES.VISUAL_LINE], {
    name: 'ITALIC',
    description: 'Italicize text',
  }, (text_format_visual_line 'italic')
  registerAction [MODES.NORMAL], {
    name: 'UNDERLINE',
    description: 'Underline text',
  }, (text_format_normal 'underline')
  registerAction [MODES.INSERT], {
    name: 'UNDERLINE',
    description: 'Underline text',
  }, (text_format_insert 'underline')
  registerAction [MODES.VISUAL], {
    name: 'UNDERLINE',
    description: 'Underline text',
  }, (text_format_visual 'underline')
  registerAction [MODES.VISUAL_LINE], {
    name: 'UNDERLINE',
    description: 'Underline text',
  }, (text_format_visual_line 'underline')
  registerAction [MODES.NORMAL], {
    name: 'STRIKETHROUGH',
    description: 'Strike through text',
  }, (text_format_normal 'strikethrough')
  registerAction [MODES.INSERT], {
    name: 'STRIKETHROUGH',
    description: 'Strike through text',
  }, (text_format_insert 'strikethrough')
  registerAction [MODES.VISUAL], {
    name: 'STRIKETHROUGH',
    description: 'Strike through text',
  }, (text_format_visual 'strikethrough')
  registerAction [MODES.VISUAL_LINE], {
    name: 'STRIKETHROUGH',
    description: 'Strike through text',
  }, (text_format_visual_line 'strikethrough')

  module?.exports = {
    actions: actionDefinitions
    motions: motionDefinitions
  }
  window?.keyDefinitions = {
    actions: actionDefinitions
    motions: motionDefinitions
  }
)()
