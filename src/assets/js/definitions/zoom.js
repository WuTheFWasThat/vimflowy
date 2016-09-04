import * as Modes from '../modes';
import keyDefinitions from '../keyDefinitions';

const MODES = Modes.modes;

const CMD_ZOOM_UP = keyDefinitions.registerCommand({
  name: 'ZOOM_UP',
  default_hotkeys: {
    normal_like: ['alt+k'],
    insert_like: ['alt+k']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_ZOOM_UP, {
  description: 'Zoom to view root\'s previous sibling',
}, async function() {
  await this.session.zoomUp();
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

const CMD_ZOOM_DOWN = keyDefinitions.registerCommand({
  name: 'ZOOM_DOWN',
  default_hotkeys: {
    normal_like: ['alt+j'],
    insert_like: ['alt+j']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_ZOOM_DOWN, {
  description: 'Zoom to view root\'s next sibling',
}, async function() {
  await this.session.zoomDown();
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

const CMD_ZOOM_IN = keyDefinitions.registerCommand({
  name: 'ZOOM_IN',
  default_hotkeys: {
    normal_like: [']', 'alt+l', 'ctrl+right'],
    insert_like: ['ctrl+right']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_ZOOM_IN, {
  description: 'Zoom in by one level',
}, async function() {
  await this.session.zoomIn();
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

const CMD_ZOOM_OUT = keyDefinitions.registerCommand({
  name: 'ZOOM_OUT',
  default_hotkeys: {
    normal_like: ['[', 'alt+h', 'ctrl+left'],
    insert_like: ['ctrl+left']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_ZOOM_OUT, {
  description: 'Zoom out by one level',
}, async function() {
  this.session.zoomOut();
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

const CMD_ZOOM_IN_ALL = keyDefinitions.registerCommand({
  name: 'ZOOM_IN_ALL',
  default_hotkeys: {
    normal_like: ['enter', 'ctrl+shift+right'],
    insert_like: ['ctrl+shift+right']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_ZOOM_IN_ALL, {
  description: 'Zoom in onto cursor',
}, async function() {
  await this.session.zoomInto(this.session.cursor.path);
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

const CMD_ZOOM_OUT_ALL = keyDefinitions.registerCommand({
  name: 'ZOOM_OUT_ALL',
  default_hotkeys: {
    normal_like: ['shift+enter', 'ctrl+shift+left'],
    insert_like: ['ctrl+shift+left']
  }
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_ZOOM_OUT_ALL, {
  description: 'Zoom out to home',
}, async function() {
  await this.session.zoomInto(this.session.document.root);
  if (this.mode === MODES.NORMAL) {
    return this.keyStream.save();
  }
});

const CMD_JUMP_PREVIOUS = keyDefinitions.registerCommand({
  name: 'JUMP_PREVIOUS',
  default_hotkeys: {
    normal_like: ['ctrl+o']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_JUMP_PREVIOUS, {
  description: 'Jump to previous location',
}, async function() {
  await this.session.jumpPrevious();
  return this.keyStream.forget(1);
});

const CMD_JUMP_NEXT = keyDefinitions.registerCommand({
  name: 'JUMP_NEXT',
  default_hotkeys: {
    normal_like: ['ctrl+i']
  }
});
keyDefinitions.registerAction([MODES.NORMAL], CMD_JUMP_NEXT, {
  description: 'Jump to next location',
}, async function() {
  await this.session.jumpNext();
  return this.keyStream.forget(1);
});
