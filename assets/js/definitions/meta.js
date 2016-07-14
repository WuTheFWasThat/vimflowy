import Modes from '../modes.coffee';
import keyDefinitions from '../keyDefinitions.coffee';

const MODES = Modes.modes;

let CMD_UNDO = keyDefinitions.registerCommand({
  name: 'UNDO',
  default_hotkeys: {
    normal_like: ['u']
  }
}
);
keyDefinitions.registerAction([MODES.NORMAL], CMD_UNDO, {
  description: 'Undo',
}, function() {
  let iterable = __range__(1, this.repeat, true);
  for (let j = 0; j < iterable.length; j++) {
    let i = iterable[j];
    this.session.undo();
  }
  return this.keyStream.forget();
}
);

let CMD_REDO = keyDefinitions.registerCommand({
  name: 'REDO',
  default_hotkeys: {
    normal_like: ['ctrl+r']
  }
}
);
keyDefinitions.registerAction([MODES.NORMAL], CMD_REDO, {
  description: 'Redo',
}, function() {
  let iterable = __range__(1, this.repeat, true);
  for (let j = 0; j < iterable.length; j++) {
    let i = iterable[j];
    this.session.redo();
  }
  return this.keyStream.forget();
}
);

let CMD_REPLAY = keyDefinitions.registerCommand({
  name: 'REPLAY',
  default_hotkeys: {
    normal_like: ['.']
  }
}
);
keyDefinitions.registerAction([MODES.NORMAL], CMD_REPLAY, {
  description: 'Replay last command',
}, function() {
  let iterable = __range__(1, this.repeat, true);
  for (let j = 0; j < iterable.length; j++) {
    let i = iterable[j];
    this.keyHandler.playRecording(this.keyStream.lastSequence);
    this.session.save();
  }
  return this.keyStream.forget();
}
);

let CMD_RECORD_MACRO = keyDefinitions.registerCommand({
  name: 'RECORD_MACRO',
  default_hotkeys: {
    normal_like: ['q']
  }
}
);
keyDefinitions.registerAction([MODES.NORMAL], CMD_RECORD_MACRO, {
  description: 'Begin/stop recording a macro',
}, function() {
  if (this.keyHandler.recording.stream === null) {
    let key = this.keyStream.dequeue();
    if (key === null) { return this.keyStream.wait(); }
    this.keyHandler.beginRecording(key);
  } else {
    // pop off the RECORD_MACRO itself
    this.keyHandler.recording.stream.queue.pop();
    this.keyHandler.finishRecording();
  }
  return this.keyStream.forget();
}
);

let CMD_PLAY_MACRO = keyDefinitions.registerCommand({
  name: 'PLAY_MACRO',
  default_hotkeys: {
    normal_like: ['@']
  }
}
);
keyDefinitions.registerAction([MODES.NORMAL], CMD_PLAY_MACRO, {
  description: 'Play a macro',
}, function() {
  let key = this.keyStream.dequeue();
  if (key === null) { return this.keyStream.wait(); }
  let recording = this.keyHandler.macros[key];
  if (recording === undefined) { return this.keyStream.forget(); }
  let iterable = __range__(1, this.repeat, true);
  for (let j = 0; j < iterable.length; j++) {
    let i = iterable[j];
    this.keyHandler.playRecording(recording);
  }
  // save the macro-playing sequence itself
  return this.keyStream.save();
}
);

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}