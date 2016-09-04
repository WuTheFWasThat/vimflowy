import keyDefinitions from '../keyDefinitions';

const CMD_LEFT = keyDefinitions.registerCommand({
  name: 'LEFT',
  default_hotkeys: {
    all: ['left'],
    normal_like: ['h']
  }
});
keyDefinitions.registerMotion(CMD_LEFT, {
  description: 'Move cursor left',
}, async function() {
  return async (cursor, options) => await cursor.left(options);
});

const CMD_RIGHT = keyDefinitions.registerCommand({
  name: 'RIGHT',
  default_hotkeys: {
    all: ['right'],
    normal_like: ['l']
  }
});
keyDefinitions.registerMotion(CMD_RIGHT, {
  description: 'Move cursor right',
}, async function() {
  return async (cursor, options) => await cursor.right(options);
});

const CMD_UP = keyDefinitions.registerCommand({
  name: 'UP',
  default_hotkeys: {
    all: ['up'],
    normal_like: ['k']
  }
});
keyDefinitions.registerMotion(CMD_UP, {
  description: 'Move cursor up',
  multirow: true
}, async function() {
  return async (cursor, options) => await cursor.up(options);
});

const CMD_DOWN = keyDefinitions.registerCommand({
  name: 'DOWN',
  default_hotkeys: {
    all: ['down'],
    normal_like: ['j']
  }
});
keyDefinitions.registerMotion(CMD_DOWN, {
  description: 'Move cursor down',
  multirow: true
}, async function() {
  return async (cursor, options) => await cursor.down(options);
});

const CMD_HOME = keyDefinitions.registerCommand({
  name: 'HOME',
  default_hotkeys: {
    all: ['home'],
    normal_like: ['0', '^'],
    insert_like: ['ctrl+a', 'meta+left']
  }
});
keyDefinitions.registerMotion(CMD_HOME, {
  description: 'Move cursor to beginning of line',
}, async function() {
  return async (cursor, options) => await cursor.home(options);
});

const CMD_END = keyDefinitions.registerCommand({
  name: 'END',
  default_hotkeys: {
    all: ['end'],
    normal_like : ['$'],
    insert_like: ['ctrl+e', 'meta+right']
  }
});
keyDefinitions.registerMotion(CMD_END, {
  description: 'Move cursor to end of line',
}, async function() {
  return async (cursor, options) => await cursor.end(options);
});

const CMD_BEGINNING_WORD = keyDefinitions.registerCommand({
  name: 'BEGINNING_WORD',
  default_hotkeys: {
    normal_like: ['b'],
    insert_like: ['alt+b', 'alt+left']
  }
});
keyDefinitions.registerMotion(CMD_BEGINNING_WORD, {
  description: 'Move cursor to the first word-beginning before it',
}, async function() {
  return async (cursor, options) =>
    await cursor.beginningWord({cursor: options});
});

const CMD_END_WORD = keyDefinitions.registerCommand({
  name: 'END_WORD',
  default_hotkeys: {
    normal_like: ['e']
  }
});
keyDefinitions.registerMotion(CMD_END_WORD, {
  description: 'Move cursor to the first word-ending after it',
}, async function() {
  return async (cursor, options) =>
    await cursor.endWord({cursor: options});
});

const CMD_NEXT_WORD = keyDefinitions.registerCommand({
  name: 'NEXT_WORD',
  default_hotkeys: {
    normal_like: ['w'],
    insert_like: ['alt+f', 'alt+right']
  }
});
keyDefinitions.registerMotion(CMD_NEXT_WORD, {
  description: 'Move cursor to the beginning of the next word',
}, async function() {
  return async (cursor, options) =>
    await cursor.nextWord({cursor: options});
});

const CMD_BEGINNING_WWORD = keyDefinitions.registerCommand({
  name: 'BEGINNING_WWORD',
  default_hotkeys: {
    normal_like: ['B']
  }
});
keyDefinitions.registerMotion(CMD_BEGINNING_WWORD, {
  description: 'Move cursor to the first Word-beginning before it',
}, async function() {
  return async (cursor, options) =>
    await cursor.beginningWord({cursor: options, whitespaceWord: true});
});

const CMD_END_WWORD = keyDefinitions.registerCommand({
  name: 'END_WWORD',
  default_hotkeys: {
    normal_like: ['E']
  }
});
keyDefinitions.registerMotion(CMD_END_WWORD, {
  description: 'Move cursor to the first Word-ending after it',
}, async function() {
  return async (cursor, options) =>
    await cursor.endWord({cursor: options, whitespaceWord: true});
});

const CMD_NEXT_WWORD = keyDefinitions.registerCommand({
  name: 'NEXT_WWORD',
  default_hotkeys: {
    normal_like: ['W']
  }
});
keyDefinitions.registerMotion(CMD_NEXT_WWORD, {
  description: 'Move cursor to the beginning of the next Word',
}, async function() {
  return async (cursor, options) =>
    await cursor.nextWord({cursor: options, whitespaceWord: true});
});

const CMD_FIND_NEXT_CHAR = keyDefinitions.registerCommand({
  name: 'FIND_NEXT_CHAR',
  default_hotkeys: {
    normal_like: ['f']
  }
});
keyDefinitions.registerMotion(CMD_FIND_NEXT_CHAR, {
  description: 'Move cursor to next occurrence of character in line',
}, async function() {
  const key = this.keyStream.dequeue();
  if (key === null) {
    this.keyStream.wait();
    return null;
  }
  return async (cursor, options) =>
    await cursor.findNextChar(key, {cursor: options});
});

const CMD_FIND_PREV_CHAR = keyDefinitions.registerCommand({
  name: 'FIND_PREV_CHAR',
  default_hotkeys: {
    normal_like: ['F']
  }
});
keyDefinitions.registerMotion(CMD_FIND_PREV_CHAR, {
  description: 'Move cursor to previous occurrence of character in line',
}, async function() {
  const key = this.keyStream.dequeue();
  if (key === null) {
    this.keyStream.wait();
    return null;
  }
  return async (cursor, options) =>
    await cursor.findPrevChar(key, {cursor: options});
});

const CMD_TO_NEXT_CHAR = keyDefinitions.registerCommand({
  name: 'TO_NEXT_CHAR',
  default_hotkeys: {
    normal_like: ['t']
  }
});
keyDefinitions.registerMotion(CMD_TO_NEXT_CHAR, {
  description: 'Move cursor to just before next occurrence of character in line',
}, async function() {
  const key = this.keyStream.dequeue();
  if (key === null) {
    this.keyStream.wait();
    return null;
  }
  return async (cursor, options) =>
    await cursor.findNextChar(key, {cursor: options, beforeFound: true});
});

const CMD_TO_PREV_CHAR = keyDefinitions.registerCommand({
  name: 'TO_PREV_CHAR',
  default_hotkeys: {
    normal_like: ['T']
  }
});
keyDefinitions.registerMotion(CMD_TO_PREV_CHAR, {
  description: 'Move cursor to just after previous occurrence of character in line',
}, async function() {
  const key = this.keyStream.dequeue();
  if (key === null) {
    this.keyStream.wait();
    return null;
  }
  return async (cursor, options) =>
    await cursor.findPrevChar(key, {cursor: options, beforeFound: true});
});

// NOTE: for normal mode, this is done within the CMD_GO tree
const CMD_GO_HOME = keyDefinitions.registerCommand({
  name: 'GO_HOME',
  default_hotkeys: {
    insert_like: ['meta+up']
  }
});
keyDefinitions.registerMotion(CMD_GO_HOME, {
  description: 'Go to beginning of visible document',
}, async function() {
  return async (cursor, options) => await cursor.visibleHome(options);
});

const CMD_GO_END = keyDefinitions.registerCommand({
  name: 'GO_END',
  default_hotkeys: {
    normal_like: ['G'],
    insert_like: ['meta+down']
  }
});
keyDefinitions.registerMotion(CMD_GO_END, {
  description: 'Go to end of visible document',
}, async function() {
  return async (cursor, options) => await cursor.visibleEnd(options);
});

const CMD_NEXT_SIBLING = keyDefinitions.registerCommand({
  name: 'NEXT_SIBLING',
  default_hotkeys: {
    normal_like: ['}'],
    insert_like: ['alt+down']
  }
});
keyDefinitions.registerMotion(CMD_NEXT_SIBLING, {
  description: 'Move cursor to the next sibling of the current line',
  multirow: true
}, async function() {
  return async (cursor, options) => await cursor.nextSibling(options);
});

const CMD_PREV_SIBLING = keyDefinitions.registerCommand({
  name: 'PREV_SIBLING',
  default_hotkeys: {
    normal_like: ['{'],
    insert_like: ['alt+up']
  }
});
keyDefinitions.registerMotion(CMD_PREV_SIBLING, {
  description: 'Move cursor to the previous sibling of the current line',
  multirow: true
}, async function() {
  return async (cursor, options) => await cursor.prevSibling(options);
});
