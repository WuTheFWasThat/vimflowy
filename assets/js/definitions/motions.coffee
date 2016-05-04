Modes = require '../modes.coffee'
keyDefinitions = require '../keyDefinitions.coffee'

MODES = Modes.modes

CMD_LEFT = keyDefinitions.registerCommand {
  name: 'LEFT'
  default_hotkeys:
    all: ['left']
    normal_like: ['h']
}
keyDefinitions.registerMotion CMD_LEFT, {
  description: 'Move cursor left',
}, () ->
  return (cursor, options) ->
    cursor.left options

CMD_RIGHT = keyDefinitions.registerCommand {
  name: 'RIGHT'
  default_hotkeys:
    all: ['right']
    normal_like: ['l']
}
keyDefinitions.registerMotion CMD_RIGHT, {
  description: 'Move cursor right',
}, () ->
  return (cursor, options) ->
    cursor.right options

CMD_UP = keyDefinitions.registerCommand {
  name: 'UP'
  default_hotkeys:
    all: ['up']
    normal_like: ['k']
}
keyDefinitions.registerMotion CMD_UP, {
  description: 'Move cursor up',
  multirow: true
}, () ->
  return (cursor, options) ->
    cursor.up options

CMD_DOWN = keyDefinitions.registerCommand {
  name: 'DOWN'
  default_hotkeys:
    all: ['down']
    normal_like: ['j']
}
keyDefinitions.registerMotion CMD_DOWN, {
  description: 'Move cursor down',
  multirow: true
}, () ->
  return (cursor, options) ->
    cursor.down options

CMD_HOME = keyDefinitions.registerCommand {
  name: 'HOME'
  default_hotkeys:
    all: ['home']
    normal_like: ['0', '^']
    insert_like: ['ctrl+a']
}
keyDefinitions.registerMotion CMD_HOME, {
  description: 'Move cursor to beginning of line',
}, () ->
  return (cursor, options) ->
    cursor.home options

CMD_END = keyDefinitions.registerCommand {
  name: 'END'
  default_hotkeys:
    all: ['end']
    normal_like : ['$']
    insert_like: ['ctrl+e']
}
keyDefinitions.registerMotion CMD_END, {
  description: 'Move cursor to end of line',
}, () ->
  return (cursor, options) ->
    cursor.end options

CMD_BEGINNING_WORD = keyDefinitions.registerCommand {
  name: 'BEGINNING_WORD'
  default_hotkeys:
    normal_like: ['b']
    insert_like: ['alt+b']
}
keyDefinitions.registerMotion CMD_BEGINNING_WORD, {
  description: 'Move cursor to the first word-beginning before it',
}, () ->
  return (cursor, options) ->
    cursor.beginningWord {cursor: options}

CMD_END_WORD = keyDefinitions.registerCommand {
  name: 'END_WORD'
  default_hotkeys:
    normal_like: ['e']
    insert_like: ['alt+f']
}
keyDefinitions.registerMotion CMD_END_WORD, {
  description: 'Move cursor to the first word-ending after it',
}, () ->
  return (cursor, options) ->
    cursor.endWord {cursor: options}

CMD_NEXT_WORD = keyDefinitions.registerCommand {
  name: 'NEXT_WORD'
  default_hotkeys:
    normal_like: ['w']
}
keyDefinitions.registerMotion CMD_NEXT_WORD, {
  description: 'Move cursor to the beginning of the next word',
}, () ->
  return (cursor, options) ->
    cursor.nextWord {cursor: options}

CMD_BEGINNING_WWORD = keyDefinitions.registerCommand {
  name: 'BEGINNING_WWORD'
  default_hotkeys:
    normal_like: ['B']
}
keyDefinitions.registerMotion CMD_BEGINNING_WWORD, {
  description: 'Move cursor to the first Word-beginning before it',
}, () ->
  return (cursor, options) ->
    cursor.beginningWord {cursor: options, whitespaceWord: true}

CMD_END_WWORD = keyDefinitions.registerCommand {
  name: 'END_WWORD'
  default_hotkeys:
    normal_like: ['E']
}
keyDefinitions.registerMotion CMD_END_WWORD, {
  description: 'Move cursor to the first Word-ending after it',
}, () ->
  return (cursor, options) ->
    cursor.endWord {cursor: options, whitespaceWord: true}

CMD_NEXT_WWORD = keyDefinitions.registerCommand {
  name: 'NEXT_WWORD'
  default_hotkeys:
    normal_like: ['W']
}
keyDefinitions.registerMotion CMD_NEXT_WWORD, {
  description: 'Move cursor to the beginning of the next Word',
}, () ->
  return (cursor, options) ->
    cursor.nextWord {cursor: options, whitespaceWord: true}

CMD_FIND_NEXT_CHAR = keyDefinitions.registerCommand {
  name: 'FIND_NEXT_CHAR'
  default_hotkeys:
    normal_like: ['f']
}
keyDefinitions.registerMotion CMD_FIND_NEXT_CHAR, {
  description: 'Move cursor to next occurrence of character in line',
}, () ->
  key = do @keyStream.dequeue
  if key == null
    do @keyStream.wait
    return null
  return (cursor, options) ->
    cursor.findNextChar key, {cursor: options}

CMD_FIND_PREV_CHAR = keyDefinitions.registerCommand {
  name: 'FIND_PREV_CHAR'
  default_hotkeys:
    normal_like: ['F']
}
keyDefinitions.registerMotion CMD_FIND_PREV_CHAR, {
  description: 'Move cursor to previous occurrence of character in line',
}, () ->
  key = do @keyStream.dequeue
  if key == null
    do @keyStream.wait
    return null
  return (cursor, options) ->
    cursor.findPrevChar key, {cursor: options}

CMD_TO_NEXT_CHAR = keyDefinitions.registerCommand {
  name: 'TO_NEXT_CHAR'
  default_hotkeys:
    normal_like: ['t']
}
keyDefinitions.registerMotion CMD_TO_NEXT_CHAR, {
  description: 'Move cursor to just before next occurrence of character in line',
}, () ->
  key = do @keyStream.dequeue
  if key == null
    do @keyStream.wait
    return null
  return (cursor, options) ->
    cursor.findNextChar key, {cursor: options, beforeFound: true}

CMD_TO_PREV_CHAR = keyDefinitions.registerCommand {
  name: 'TO_PREV_CHAR'
  default_hotkeys:
    normal_like: ['T']
}
keyDefinitions.registerMotion CMD_TO_PREV_CHAR, {
  description: 'Move cursor to just after previous occurrence of character in line',
}, () ->
  key = do @keyStream.dequeue
  if key == null
    do @keyStream.wait
    return null
  return (cursor, options) ->
    cursor.findPrevChar key, {cursor: options, beforeFound: true}

CMD_GO_END = keyDefinitions.registerCommand {
  name: 'GO_END'
  default_hotkeys:
    normal_like: ['G']
}
keyDefinitions.registerMotion CMD_GO_END, {
  description: 'Go to end of visible document',
}, () ->
  return (cursor, options) ->
    cursor.visibleEnd options

CMD_NEXT_SIBLING = keyDefinitions.registerCommand {
  name: 'NEXT_SIBLING'
  default_hotkeys:
    normal_like: ['}']
}
keyDefinitions.registerMotion CMD_NEXT_SIBLING, {
  description: 'Move cursor to the next sibling of the current line',
  multirow: true
}, () ->
  return (cursor, options) ->
    cursor.nextSibling options

CMD_PREV_SIBLING = keyDefinitions.registerCommand {
  name: 'PREV_SIBLING'
  default_hotkeys:
    normal_like: ['{']
}
keyDefinitions.registerMotion CMD_PREV_SIBLING, {
  description: 'Move cursor to the previous sibling of the current line',
  multirow: true
}, () ->
  return (cursor, options) ->
    cursor.prevSibling options
