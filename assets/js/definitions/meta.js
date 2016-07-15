import Modes from '../modes';
import keyDefinitions from '../keyDefinitions';

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
  for (let j = 0; j < this.repeat; j++) {
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
  for (let j = 0; j < this.repeat; j++) {
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
  for (let j = 0; j < this.repeat; j++) {
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
  for (let j = 0; j < this.repeat; j++) {
    this.keyHandler.playRecording(recording);
  }
  // save the macro-playing sequence itself
  return this.keyStream.save();
});
