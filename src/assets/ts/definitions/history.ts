import keyDefinitions, { Action, SequenceAction } from '../keyDefinitions';
import { Key, Macro } from '../types';

keyDefinitions.registerAction(new Action(
  'undo',
  'Undo',
  async function({ session, repeat }) {
    for (let j = 0; j < repeat; j++) {
      await session.undo();
    }
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'redo',
  'Redo',
  async function({ session, repeat }) {
    for (let j = 0; j < repeat; j++) {
      await session.redo();
    }
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'replay-command',
  'Replay last command',
  async function({ repeat, keyStream, keyHandler }) {
    for (let j = 0; j < repeat; j++) {
      await keyHandler.playRecording(keyStream.lastSequence);
    }
  },
  { sequence: SequenceAction.DROP },
));

// TODO: store this on session?  dont assume global
let RECORDING: {
  macro: Macro,
  key: Key,
} | null = null;
const RECORDING_LISTENER = (key: Key) => {
  if (!RECORDING) {
    throw new Error('Recording listener on while there was no recording');
  }
  // TODO avoid recording RECORD_MACRO itself?
  // current record_macro implementation pops itself off
  // and assumes it's only 1 key
  RECORDING.macro.push(key);
};

keyDefinitions.registerAction(new Action(
  'record-macro',
  'Begin/stop recording a macro',
  async function({ keyStream, session }) {
    if (RECORDING === null) {
      const key = await keyStream.dequeue();
      RECORDING = {
        macro: [],
        key: key,
      };
      keyStream.on('dequeue', RECORDING_LISTENER);
    } else {
      // pop off the RECORD_MACRO itself
      RECORDING.macro.pop();
      const macros = session.clientStore.getMacros();
      const macro = RECORDING.macro;
      macros[RECORDING.key] = macro;
      session.clientStore.setMacros(macros);
      RECORDING = null;
      keyStream.off('dequeue', RECORDING_LISTENER);
    }
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'play-macro',
  'Play a macro',
  async function({ keyStream, keyHandler, repeat, session }) {
    const key = await keyStream.dequeue();
    const macros = session.clientStore.getMacros();
    const recording = macros[key];
    if (recording == null) {
      keyStream.drop();
      return;
    }
    for (let j = 0; j < repeat; j++) {
      await keyHandler.playRecording(recording);
    }
  },
));
