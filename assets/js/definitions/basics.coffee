Modes = require '../modes.coffee'
utils = require '../utils.coffee'
keyDefinitions = require '../keyDefinitions.coffee'

MODES = Modes.modes

# TODO: SWAP_CASE         : ['~']

# TODO: THIS IS A HACK...
CMD_MOTION = {name: 'MOTION'}

keyDefinitions.registerAction [MODES.NORMAL], CMD_MOTION, {
  description: 'Move the cursor',
}, (motion) ->
  for i in [1..@repeat]
    motion @session.cursor, {}
  do @keyStream.forget
keyDefinitions.registerAction [MODES.INSERT], CMD_MOTION, {
  description: 'Move the cursor',
}, (motion) ->
  motion @session.cursor, {pastEnd: true}
keyDefinitions.registerAction [MODES.VISUAL], CMD_MOTION, {
  description: 'Move the cursor',
}, (motion) ->
  # this is necessary until we figure out multiline
  tmp = do @session.cursor.clone
  for i in [1..@repeat]
    motion tmp, {pastEnd: true}

  if not (tmp.path.is @session.cursor.path) # only allow same-row movement
    @session.showMessage "Visual mode currently only works on one line", {text_class: 'error'}
  else
    @session.cursor.from tmp
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_MOTION, {
  description: 'Move the cursor',
}, (motion) ->
  for i in [1..@repeat]
    motion @session.cursor, {pastEnd: true}
keyDefinitions.registerAction [MODES.SEARCH], CMD_MOTION, {
  description: 'Move the cursor',
}, (motion) ->
  motion @session.menu.session.cursor, {pastEnd: true}

CMD_HELP = keyDefinitions.registerCommand {
  name: 'HELP'
  default_hotkeys:
    insert_like: ['ctrl+?']
    normal_like: ['?']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.VISUAL, MODES.VISUAL_LINE, MODES.INSERT, MODES.SEARCH], CMD_HELP, {
  description: 'Show/hide key bindings (edit in settings)',
}, () ->
  do @session.toggleBindingsDiv
  @keyStream.forget 1

# TODO: flesh out settings menu commands (in separate file)
# CMD_SETTINGS = keyDefinitions.registerCommand {
#   name: 'SETTINGS'
#   default_hotkeys:
#     normal_like: [':']
# }
# keyDefinitions.registerAction [MODES.NORMAL], CMD_SETTINGS, {
#   description: 'Open settings menu',
# }, () ->
#   @session.setMode MODES.SETTINGS

CMD_INSERT = keyDefinitions.registerCommand {
  name: 'INSERT'
  default_hotkeys:
    normal_like: ['i']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT, {
  description: 'Insert at character',
}, () ->
  @session.setMode MODES.INSERT

CMD_INSERT_AFTER = keyDefinitions.registerCommand {
  name: 'INSERT_AFTER'
  default_hotkeys:
    normal_like: ['a']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_AFTER, {
  description: 'Insert after character',
}, () ->
  @session.setMode MODES.INSERT
  @session.cursor.right {pastEnd: true}

CMD_INSERT_HOME = keyDefinitions.registerCommand {
  name: 'INSERT_HOME'
  default_hotkeys:
    normal_like: ['I']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_HOME, {
  description: 'Insert at beginning of line',
}, () ->
  @session.setMode MODES.INSERT
  do @session.cursor.home

CMD_INSERT_END = keyDefinitions.registerCommand {
  name: 'INSERT_END'
  default_hotkeys:
    normal_like: ['A']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_END, {
  description: 'Insert after end of line',
}, () ->
  @session.setMode MODES.INSERT
  @session.cursor.end {pastEnd: true}

CMD_INSERT_LINE_BELOW = keyDefinitions.registerCommand {
  name: 'INSERT_LINE_BELOW'
  default_hotkeys:
    normal_like: ['o']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_LINE_BELOW, {
  description: 'Insert on new line after current line',
}, () ->
  @session.setMode MODES.INSERT
  do @session.newLineBelow

CMD_INSERT_LINE_ABOVE = keyDefinitions.registerCommand {
  name: 'INSERT_LINE_ABOVE'
  default_hotkeys:
    normal_like: ['O']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_INSERT_LINE_ABOVE, {
  description: 'Insert on new line before current line',
}, () ->
  @session.setMode MODES.INSERT
  do @session.newLineAbove

CMD_GO = keyDefinitions.registerCommand {
  name: 'GO'
  default_hotkeys:
    normal_like: ['g']
}

# TODO: change this
keyDefinitions.registerMotion CMD_GO, {
  description: 'Various commands for navigation (operator)',
  multirow: true
}, {}

keyDefinitions.registerMotion [CMD_GO, CMD_GO], {
  description: 'Go to the beginning of visible document',
  multirow: true
}, () ->
  return (cursor, options) ->
    cursor.visibleHome options

CMD_PARENT = keyDefinitions.registerCommand {
  name: 'PARENT'
  default_hotkeys:
    normal_like: ['p']
}

keyDefinitions.registerMotion [CMD_GO, CMD_PARENT], {
  description: 'Go to the parent of current line',
  multirow: true
}, () ->
  return (cursor, options) ->
    cursor.parent options

CMD_CLONE = keyDefinitions.registerCommand {
  name: 'CLONE'
  default_hotkeys:
    normal_like: ['c']
}
keyDefinitions.registerMotion [CMD_GO, CMD_CLONE], {
  description: 'Go to next copy of this clone'
  multirow: true
}, () ->
  return (cursor, options) =>
    if @session.mode != MODES.NORMAL
      # doesn't work for visual_line mode due to zoomInto
      return
    newPath = @session.document.nextClone cursor.path
    cursor.setPath newPath
    if not @session.isVisible newPath
      @session.zoomInto newPath

CMD_LINK = keyDefinitions.registerCommand {
  name: 'LINK'
  default_hotkeys:
    normal_like: ['x']
}
# TODO: this isn't actually a motion, but that's okay for now...
keyDefinitions.registerMotion [CMD_GO, CMD_LINK], {
  description: 'Visit to the link indicated by the cursor, in a new tab',
},  () ->
  return (cursor) =>
    word = @session.document.getWord cursor.row, cursor.col
    if utils.isLink word
      window.open word

####################
# ACTIONS
####################

visual_line_mode_delete_fn = () ->
  return () ->
    @session.delBlocks @parent.row, @row_start_i, @num_rows, {addNew: false}
    @session.setMode MODES.NORMAL
    do @keyStream.save

visual_mode_delete_fn = () ->
  return () ->
    options = {includeEnd: true, yank: true}
    @session.deleteBetween @session.cursor, @session.anchor, options
    @session.setMode MODES.NORMAL
    do @keyStream.save

CMD_TOGGLE_FOLD = keyDefinitions.registerCommand {
  name: 'TOGGLE_FOLD'
  default_hotkeys:
    normal_like: ['z']
    insert_like: ['ctrl+z']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_TOGGLE_FOLD, {
  description: 'Toggle whether a block is folded',
}, () ->
  do @session.toggleCurBlockCollapsed
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_REPLACE = keyDefinitions.registerCommand {
  name: 'REPLACE'
  default_hotkeys:
    normal_like: ['r']
}
# TODO: visual and visual_line mode
keyDefinitions.registerAction [MODES.NORMAL], CMD_REPLACE, {
  description: 'Replace character',
}, () ->
  key = do @keyStream.dequeue
  if key == null then return do @keyStream.wait
  # TODO: refactor keys so this is unnecessary
  if key == 'space' then key = ' '
  @session.replaceCharsAfterCursor key, @repeat
  do @keyStream.save

CMD_DELETE = keyDefinitions.registerCommand {
  name: 'DELETE'
  default_hotkeys:
    normal_like: ['d']
}
keyDefinitions.registerAction [MODES.VISUAL], CMD_DELETE, {
  description: 'Delete',
}, (do visual_mode_delete_fn)
keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_DELETE, {
  description: 'Delete',
}, (do visual_line_mode_delete_fn)

keyDefinitions.registerAction [MODES.NORMAL], CMD_DELETE, {
  description: 'Delete (operator)',
}, {}
keyDefinitions.registerAction [MODES.NORMAL], [CMD_DELETE, CMD_DELETE], {
  description: 'Delete blocks'
}, () ->
  @session.delBlocksAtCursor @repeat, {addNew: false}
  do @keyStream.save
keyDefinitions.registerAction [MODES.NORMAL], [CMD_DELETE, CMD_MOTION], {
  description: 'Delete from cursor with motion'
}, (motion) ->
  cursor = do @session.cursor.clone
  for i in [1..@repeat]
    motion cursor, {pastEnd: true, pastEndWord: true}

  @session.deleteBetween @session.cursor, cursor, { yank: true }
  do @keyStream.save

CMD_RECURSIVE = keyDefinitions.registerCommand {
  name: 'RECURSIVE'
  default_hotkeys:
    normal_like: ['r']
}

#################
# change
#################

CMD_CHANGE = keyDefinitions.registerCommand {
  name: 'CHANGE'
  default_hotkeys:
    normal_like: ['c']
}

keyDefinitions.registerAction [MODES.VISUAL], CMD_CHANGE, {
  description: 'Change',
}, () ->
  options = {includeEnd: true, yank: true}
  @session.deleteBetween @session.cursor, @session.anchor, options
  @session.setMode MODES.INSERT

keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_CHANGE, {
  description: 'Change',
}, () ->
  @session.delBlocks @parent.row, @row_start_i, @num_rows, {addNew: true}
  @session.setMode MODES.INSERT

keyDefinitions.registerAction [MODES.NORMAL], CMD_CHANGE, {
  description: 'Change (operator)',
}, {}

# TODO: support repeat?
keyDefinitions.registerAction [MODES.NORMAL], [CMD_CHANGE, CMD_CHANGE], {
  description: 'Delete row, and enter insert mode'
}, () ->
  @session.setMode MODES.INSERT
  @session.clearRowAtCursor {yank: true}

keyDefinitions.registerAction [MODES.NORMAL], [CMD_CHANGE, CMD_RECURSIVE], {
  description: 'Delete blocks, and enter insert mode'
}, () ->
  @session.setMode MODES.INSERT
  @session.delBlocksAtCursor @repeat, {addNew: true}

keyDefinitions.registerAction [MODES.NORMAL], [CMD_CHANGE, CMD_MOTION], {
  description: 'Delete from cursor with motion, and enter insert mode'
}, (motion) ->
  cursor = do @session.cursor.clone
  for i in [1..@repeat]
    motion cursor, {pastEnd: true, pastEndWord: true}
  @session.setMode MODES.INSERT
  @session.deleteBetween @session.cursor, cursor, {yank: true}

#################
# yank
#################

CMD_YANK = keyDefinitions.registerCommand {
  name: 'YANK'
  default_hotkeys:
    normal_like: ['y']
}

keyDefinitions.registerAction [MODES.VISUAL], CMD_YANK, {
  description: 'Yank',
}, () ->
  options = {includeEnd: true}
  @session.yankBetween @session.cursor, @session.anchor, options
  @session.setMode MODES.NORMAL
  do @keyStream.forget

keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_YANK, {
  description: 'Yank',
}, () ->
  @session.yankBlocks @row_start, @num_rows
  @session.setMode MODES.NORMAL
  do @keyStream.forget

keyDefinitions.registerAction [MODES.NORMAL], CMD_YANK, {
  description: 'Yank (operator)',
}, {}

# TODO: support repeat?
keyDefinitions.registerAction [MODES.NORMAL], [CMD_YANK, CMD_YANK], {
  description: 'Yank row'
}, () ->
  do @session.yankRowAtCursor
  do @keyStream.forget

keyDefinitions.registerAction [MODES.NORMAL], [CMD_YANK, CMD_RECURSIVE], {
  description: 'Yank blocks'
}, () ->
  @session.yankBlocksAtCursor @repeat
  do @keyStream.forget

keyDefinitions.registerAction [MODES.NORMAL], [CMD_YANK, CMD_MOTION], {
  description: 'Yank from cursor with motion'
}, (motion) ->
  cursor = do @session.cursor.clone
  for i in [1..@repeat]
    motion cursor, {pastEnd: true, pastEndWord: true}

  @session.yankBetween @session.cursor, cursor, {}
  do @keyStream.forget

keyDefinitions.registerAction [MODES.NORMAL], [CMD_YANK, CMD_CLONE], {
  description: 'Yank blocks as a clone'
}, () ->
  @session.yankBlocksCloneAtCursor @repeat
  do @keyStream.forget

#   jeff: c conflicts with change, so this doesn't work
# keyDefinitions.registerAction [MODES.VISUAL_LINE],  CMD_CLONE, {
#   description: 'Yank blocks as a clone',
# }, () ->
#   @session.yankBlocksClone @row_start, @num_rows
#   @session.setMode MODES.NORMAL
#   do @keyStream.forget

#################
# delete
#################

CMD_DELETE_CHAR = keyDefinitions.registerCommand {
  name: 'DELETE_CHAR'
  default_hotkeys:
    normal_like: ['x']
    insert_like: ['delete']
}

keyDefinitions.registerAction [MODES.NORMAL], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, () ->
  @session.delCharsAfterCursor @repeat, {yank: true}
  do @keyStream.save

keyDefinitions.registerAction [MODES.VISUAL], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, (do visual_mode_delete_fn)

keyDefinitions.registerAction [MODES.VISUAL_LINE], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, (do visual_line_mode_delete_fn)

keyDefinitions.registerAction [MODES.INSERT], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, () ->
  @session.delCharsAfterCursor 1

keyDefinitions.registerAction [MODES.SEARCH], CMD_DELETE_CHAR, {
  description: 'Delete character at the cursor (i.e. del key)',
}, () ->
  @session.menu.session.delCharsAfterCursor 1

CMD_DELETE_LAST_CHAR = keyDefinitions.registerCommand {
  name: 'DELETE_LAST_CHAR'
  default_hotkeys:
    normal_like: ['X']
    insert_like: ['backspace', 'shift+backspace']
}

keyDefinitions.registerAction [MODES.NORMAL], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, () ->
  num = Math.min @session.cursor.col, @repeat
  if num > 0
    @session.delCharsBeforeCursor num, {yank: true}
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
  do @session.deleteAtCursor

keyDefinitions.registerAction [MODES.SEARCH], CMD_DELETE_LAST_CHAR, {
  description: 'Delete last character (i.e. backspace key)',
}, () ->
  do @session.menu.session.deleteAtCursor

CMD_CHANGE_CHAR = keyDefinitions.registerCommand {
  name: 'CHANGE_CHAR'
  default_hotkeys:
    normal_like: ['s']
}

keyDefinitions.registerAction [MODES.NORMAL], CMD_CHANGE_CHAR, {
  description: 'Change character',
}, () ->
  @session.setMode MODES.INSERT
  @session.delCharsAfterCursor 1, {yank: true}

CMD_DELETE_TO_HOME = keyDefinitions.registerCommand {
  name: 'DELETE_TO_HOME'
  default_hotkeys:
    normal_like: []
    insert_like: ['ctrl+u']
}
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
  @session.deleteBetween @session.cursor, @session.cursor.clone().home(options.cursor), options
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_DELETE_TO_END = keyDefinitions.registerCommand {
  name: 'DELETE_TO_END'
  default_hotkeys:
    normal_like: ['D']
    insert_like: ['ctrl+k']
}
# keyDefinitions.registerActionAsMacro CMD_DELETE_TO_END, [CMD_DELETE, CMD_END]
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
  @session.deleteBetween @session.cursor, @session.cursor.clone().end(options.cursor), options
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_DELETE_LAST_WORD = keyDefinitions.registerCommand {
  name: 'DELETE_LAST_WORD'
  default_hotkeys:
    normal_like: []
    insert_like: ['ctrl+w']
}
# keyDefinitions.registerActionAsMacro CMD_DELETE_LAST_WORD, [CMD_DELETE, CMD_BEGINNING_WWORD]
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
  @session.deleteBetween @session.cursor, @session.cursor.clone().beginningWord({cursor: options.cursor, whitespaceWord: true}), options
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_PASTE_AFTER = keyDefinitions.registerCommand {
  name: 'PASTE_AFTER'
  default_hotkeys:
    normal_like: ['p']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_PASTE_AFTER, {
  description: 'Paste after cursor',
}, () ->
  do @session.pasteAfter
  do @keyStream.save
# NOTE: paste after doesn't make sense for insert mode

CMD_PASTE_BEFORE = keyDefinitions.registerCommand {
  name: 'PASTE_BEFORE'
  default_hotkeys:
    normal_like: ['P']
    insert_like: ['ctrl+y']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_PASTE_BEFORE, {
  description: 'Paste before cursor',
}, () ->
  do @session.pasteBefore
  do @keyStream.save
keyDefinitions.registerAction [MODES.INSERT], CMD_PASTE_BEFORE, {
  description: 'Paste before cursor',
}, () ->
  do @session.pasteBefore

CMD_JOIN_LINE = keyDefinitions.registerCommand {
  name: 'JOIN_LINE'
  default_hotkeys:
    normal_like: ['J']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_JOIN_LINE, {
  description: 'Join current line with line below',
}, () ->
  do @session.joinAtCursor
  do @keyStream.save

CMD_SPLIT_LINE = keyDefinitions.registerCommand {
  name: 'SPLIT_LINE'
  default_hotkeys:
    normal_like: ['K']
    insert_like: ['enter']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_SPLIT_LINE, {
  description: 'Split line at cursor (i.e. enter key)',
}, () ->
  do @session.newLineAtCursor
  if @mode == MODES.NORMAL
    do @keyStream.save

CMD_SCROLL_DOWN = keyDefinitions.registerCommand {
  name: 'SCROLL_DOWN'
  default_hotkeys:
    all: ['page down']
    normal_like: ['ctrl+d']
    insert_like: ['ctrl+down']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_SCROLL_DOWN, {
  description: 'Scroll half window down',
}, () ->
  @session.scroll 0.5
  @keyStream.forget 1

CMD_SCROLL_UP = keyDefinitions.registerCommand {
  name: 'SCROLL_UP'
  default_hotkeys:
    all: ['page up']
    normal_like: ['ctrl+u']
    insert_like: ['ctrl+up']
}
keyDefinitions.registerAction [MODES.NORMAL, MODES.INSERT], CMD_SCROLL_UP, {
  description: 'Scroll half window up',
}, () ->
  @session.scroll -0.5
  @keyStream.forget 1

# for everything but normal mode
CMD_EXIT_MODE = keyDefinitions.registerCommand {
  name: 'EXIT_MODE'
  default_hotkeys:
    all: ['esc', 'ctrl+c']
}
keyDefinitions.registerAction [MODES.VISUAL, MODES.VISUAL_LINE, MODES.SEARCH, MODES.SETTINGS], CMD_EXIT_MODE, {
  description: 'Exit back to normal mode',
}, () ->
  @session.setMode MODES.NORMAL
  do @keyStream.forget
keyDefinitions.registerAction [MODES.INSERT], CMD_EXIT_MODE, {
  description: 'Exit back to normal mode',
}, () ->
  do @session.cursor.left
  @session.setMode MODES.NORMAL
  # unlike other modes, esc in insert mode keeps changes
  do @keyStream.save

# for visual and visual line mode
CMD_ENTER_VISUAL = keyDefinitions.registerCommand {
  name: 'ENTER_VISUAL'
  default_hotkeys:
    normal_like: ['v']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_ENTER_VISUAL, {
  description: 'Enter visual mode',
}, () ->
  @session.setMode MODES.VISUAL

CMD_ENTER_VISUAL_LINE = keyDefinitions.registerCommand {
  name: 'ENTER_VISUAL_LINE'
  default_hotkeys:
    normal_like: ['V']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_ENTER_VISUAL_LINE, {
  description: 'Enter visual line mode',
}, () ->
  @session.setMode MODES.VISUAL_LINE

CMD_SWAP_CURSOR = keyDefinitions.registerCommand {
  name: 'SWAP_CURSOR'
  default_hotkeys:
    normal_like: ['o', 'O']
}
keyDefinitions.registerAction [MODES.VISUAL, MODES.VISUAL_LINE], CMD_SWAP_CURSOR, {
  description: 'Swap cursor to other end of selection, in visual and visual line mode',
}, () ->
  tmp = do @session.anchor.clone
  @session.anchor.from @session.cursor
  @session.cursor.from tmp
  do @keyStream.save

exports.CMD_MOTION = CMD_MOTION
exports.CMD_DELETE_LAST_CHAR = CMD_DELETE_LAST_CHAR
exports.CMD_DELETE_CHAR = CMD_DELETE_CHAR
exports.CMD_HELP = CMD_HELP
exports.CMD_EXIT_MODE = CMD_EXIT_MODE
