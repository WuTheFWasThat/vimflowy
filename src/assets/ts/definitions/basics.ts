import { isLink } from '../utils/text';
import keyDefinitions, { Action, ActionContext, SequenceAction } from '../keyDefinitions';

keyDefinitions.registerAction(new Action(
  'move-cursor-normal',
  'Move the cursor (according to the specified motion)',
  async function(context) {
    const { motion, session, repeat } = context;
    if (motion == null) {
      throw new Error('Motion command was not passed a motion');
    }
    const tmp = session.cursor.clone();
    for (let j = 0; j < repeat; j++) {
      await motion(tmp, {});
    }
    if (await session.isVisible(tmp.path)) {
      await session.cursor.from(tmp);
    }
  },
  { sequence: SequenceAction.DROP, acceptsMotion: true },
));

keyDefinitions.registerAction(new Action(
  'move-cursor-insert',
  'Move the cursor (according to the specified motion)',
  async function(context) {
    const { motion, session } = context;
    if (motion == null) {
      throw new Error('Motion command was not passed a motion');
    }
    await motion(session.cursor, {pastEnd: true});
  },
  { acceptsMotion: true },
));

keyDefinitions.registerAction(new Action(
  'move-cursor-visual',
  'Move the cursor (according to the specified motion)',
  async function(context) {
    const { motion, session, repeat } = context;
    if (motion == null) {
      throw new Error('Motion command was not passed a motion');
    }
    // this is necessary until we figure out multiline
    const tmp = session.cursor.clone();
    for (let j = 0; j < repeat; j++) {
      await motion(tmp, {pastEnd: true});
    }

    if (!tmp.path.is(session.cursor.path)) { // only allow same-row movement
      session.showMessage('Visual mode currently only works on one line', {text_class: 'error'});
    } else {
      await session.cursor.from(tmp);
    }
  },
  { acceptsMotion: true },
));

keyDefinitions.registerAction(new Action(
  'move-cursor-visual-line',
  'Move the cursor (according to the specified motion)',
  async function(context) {
    const { motion, session, repeat } = context;
    if (motion == null) {
      throw new Error('Motion command was not passed a motion');
    }
    for (let j = 0; j < repeat; j++) {
      await motion(session.cursor, {pastEnd: true});
    }
  },
  { acceptsMotion: true },
));

keyDefinitions.registerAction(new Action(
  'toggle-help',
  'Show/hide key bindings (edit in settings)',
  async function({ session }) {
    session.toggleBindingsDiv();
  },
  { sequence: SequenceAction.DROP },
));

// TODO: have ':' in normal mode open set to SETTINGS?
keyDefinitions.registerAction(new Action(
  'enter-insert-before-cursor',
  'Insert at character',
  async function({ session }) {
    await session.setMode('INSERT');
  },
));

keyDefinitions.registerAction(new Action(
  'enter-insert-after-cursor',
  'Insert after character',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.cursor.right({pastEnd: true});
  },
));

keyDefinitions.registerAction(new Action(
  'enter-insert-line-beginning',
  'Insert at beginning of line',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.cursor.home();
  },
));

keyDefinitions.registerAction(new Action(
  'enter-insert-line-end',
  'Insert after end of line',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.cursor.end({pastEnd: true});
  },
));

keyDefinitions.registerAction(new Action(
  'enter-insert-below-line',
  'Insert on new line after current line',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.newLineBelow();
  },
));

keyDefinitions.registerAction(new Action(
  'enter-insert-above-line',
  'Insert on new line before current line',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.newLineAbove();
  },
));

keyDefinitions.registerAction(new Action(
  'visit-link',
  'Visit the link indicated by the cursor, in a new tab',
  async function({ session }) {
    const word = await session.document.getWord(session.cursor.row, session.cursor.col);
    if (isLink(word)) {
      window.open(word);
    } else {
      session.showMessage(`Tried to open non-link: ${word}`, {text_class: 'error'});
    }
  },
  { sequence: SequenceAction.DROP },
));

// ACTIONS
keyDefinitions.registerAction(new Action(
  'fold-toggle',
  'Toggle whether a block is folded',
  async function({ session }) {
    await session.toggleCurBlockCollapsed();
  },
));

keyDefinitions.registerAction(new Action(
  'fold-open',
  'Open a collapsed block',
  async function({ session }) {
    await session.setCurBlockCollapsed(false);
  },
));

keyDefinitions.registerAction(new Action(
  'fold-close',
  'Close a collapsed block',
  async function({ session }) {
    await session.setCurBlockCollapsed(true);
  },
));

keyDefinitions.registerAction(new Action(
  'replace-char',
  'Replace character(s)',
  async function({ session, keyStream, repeat }) {
    let key = await keyStream.dequeue();
    // TODO: refactor keys so this is unnecessary
    if (key === 'space') { key = ' '; }
    await session.replaceCharsAfterCursor(key, repeat);
  },
));

keyDefinitions.registerAction(new Action(
  'visual-delete',
  'Delete visual selection',
  async function({ session }) {
    const options = {includeEnd: true, yank: true};
    await session.deleteBetween(session.cursor, session.anchor, options);
    await session.setMode('NORMAL');
  },
));

keyDefinitions.registerAction(new Action(
  'visual-line-delete',
  'Delete visual line selection',
  async function({ session, visual_line }) {
    if (visual_line == null) {
      throw new Error('Visual_line mode arguments missing');
    }
    await session.delBlocks(visual_line.parent.row, visual_line.start_i, visual_line.num_rows, {addNew: false});
    await session.setMode('NORMAL');
  },
));

keyDefinitions.registerAction(new Action(
  'delete-motion',
  'Delete from cursor with motion',
  async function({ motion, session, repeat }) {
    if (motion == null) {
      throw new Error('Delete motion command was not passed a motion');
    }
    const cursor = session.cursor.clone();
    for (let j = 0; j < repeat; j++) {
      await motion(cursor, {pastEnd: true, pastEndWord: true});
    }

    await session.deleteBetween(session.cursor, cursor, { yank: true });
  },
  { acceptsMotion: true },
));

keyDefinitions.registerAction(new Action(
  'delete-blocks',
  'Delete block',
  async function({ session, repeat }) {
    await session.delBlocksAtCursor(repeat, {addNew: false});
  },
));

// change

keyDefinitions.registerAction(new Action(
  'visual-change',
  'Change',
  async function({ session }) {
    const options = {includeEnd: true, yank: true};
    await session.deleteBetween(session.cursor, session.anchor, options);
    await session.setMode('INSERT');
  },
));

keyDefinitions.registerAction(new Action(
  'visual-line-change',
  'Change',
  async function({ session, visual_line }) {
    if (visual_line == null) {
      throw new Error('Visual_line mode arguments missing');
    }
    await session.delBlocks(visual_line.parent.row, visual_line.start_i, visual_line.num_rows, {addNew: true});
    await session.setMode('INSERT');
  },
));

// TODO: support repeat?
keyDefinitions.registerAction(new Action(
  'change-line',
  'Delete row, and enter insert mode',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.clearRowAtCursor({yank: true});
  },
));

keyDefinitions.registerAction(new Action(
  'change-blocks',
  'Delete blocks, and enter insert mode',
  async function({ session, repeat }) {
    await session.setMode('INSERT');
    await session.delBlocksAtCursor(repeat, {addNew: true});
  },
));

keyDefinitions.registerAction(new Action(
  'change-motion',
  'Delete from cursor with motion, and enter insert mode',
  async function({ session, repeat, motion }) {
    if (motion == null) {
      throw new Error('Change motion command was not passed a motion');
    }
    const cursor = session.cursor.clone();
    for (let j = 0; j < repeat; j++) {
      await motion(cursor, {pastEnd: true, pastEndWord: true});
    }
    await session.setMode('INSERT');
    await session.deleteBetween(session.cursor, cursor, {yank: true});
  },
  { acceptsMotion: true },
));

keyDefinitions.registerComposedAction(
  'change-to-line-end',
  'Delete to the end of the line, and enter insert mode',
  ['change-motion', 'motion-line-end']
);

// yank

keyDefinitions.registerAction(new Action(
  'visual-yank',
  'Yank',
  async function({ session }) {
    const options = {includeEnd: true};
    await session.yankBetween(session.cursor, session.anchor, options);
    await session.setMode('NORMAL');
  },
  { sequence: SequenceAction.DROP_ALL },
));

keyDefinitions.registerAction(new Action(
  'visual-line-yank',
  'Yank',
  async function({ session, visual_line }) {
    if (visual_line == null) {
      throw new Error('Visual_line mode arguments missing');
    }
    await session.yankBlocks(visual_line.start, visual_line.num_rows);
    await session.setMode('NORMAL');
  },
  { sequence: SequenceAction.DROP_ALL },
));

// TODO: support repeat?
keyDefinitions.registerAction(new Action(
  'yank-line',
  'Yank row',
  async function({ session }) {
    await session.yankRowAtCursor();
  },
));

keyDefinitions.registerAction(new Action(
  'yank-blocks',
  'Yank blocks',
  async function({ session, repeat }) {
    await session.yankBlocksAtCursor(repeat);
  },
));

keyDefinitions.registerAction(new Action(
  'yank-motion',
  'Yank from cursor with motion',
  async function({ session, motion, repeat }) {
    if (motion == null) {
      throw new Error('Yank motion command was not passed a motion');
    }
    const cursor = session.cursor.clone();
    for (let j = 0; j < repeat; j++) {
      await motion(cursor, {pastEnd: true, pastEndWord: true});
    }

    await session.yankBetween(session.cursor, cursor, {});
  },
  { acceptsMotion: true },
));

keyDefinitions.registerComposedAction(
  'yank-to-line-end',
  'Yank to the end of the line',
  ['yank-motion', 'motion-line-end']
);

keyDefinitions.registerAction(new Action(
  'yank-clone',
  'Yank blocks as a clone',
  async function({ session, repeat }) {
    await session.yankBlocksCloneAtCursor(repeat);
  },
));

keyDefinitions.registerAction(new Action(
  'visual-line-yank-clone',
  'Yank blocks as a clone',
  async function({ session, visual_line }) {
    if (visual_line == null) {
      throw new Error('Visual_line mode arguments missing');
    }
    await session.yankBlocksClone(visual_line.start, visual_line.num_rows);
    await session.setMode('NORMAL');
  },
));

// delete

keyDefinitions.registerAction(new Action(
  'normal-delete-char',
  'Delete character at the cursor',
  async function({ session, repeat }) {
    await session.delCharsAfterCursor(repeat, {yank: true});
  },
));

keyDefinitions.registerAction(new Action(
  'delete-char-after',
  'Delete character after the cursor (i.e. del key)',
  async function({ session }) {
    await session.delCharsAfterCursor(1);
  },
));

keyDefinitions.registerAction(new Action(
  'normal-delete-char-before',
  'Delete previous character',
  async function({ session, repeat }) {
    const num = Math.min(session.cursor.col, repeat);
    if (num > 0) {
      await session.delCharsBeforeCursor(num, {yank: true});
    }
  },
));
// behaves like row delete, in visual line

keyDefinitions.registerAction(new Action(
  'delete-char-before',
  'Delete previous character (i.e. backspace key)',
  async function({ session }) {
    await session.deleteAtCursor();
  },
));

keyDefinitions.registerAction(new Action(
  'change-char',
  'Change character',
  async function({ session }) {
    await session.setMode('INSERT');
    await session.delCharsAfterCursor(1, {yank: true});
  },
));

keyDefinitions.registerComposedAction(
  'delete-to-line-beginning',
  'Delete to the beginning of the line',
  ['delete-motion', 'motion-line-beginning']
);

keyDefinitions.registerComposedAction(
  'delete-to-line-end',
  'Delete to the end of the line',
  ['delete-motion', 'motion-line-end']
);

keyDefinitions.registerComposedAction(
  'delete-to-word-beginning',
  'Delete to the beginning of the previous word',
  ['delete-motion', 'motion-word-beginning']
);

keyDefinitions.registerAction(new Action(
  'paste-after',
  'Paste after cursor',
  async function({ session }) {
    await session.pasteAfter();
  },
));

keyDefinitions.registerAction(new Action(
  'paste-before',
  'Paste before cursor',
  async function({ session }) {
    await session.pasteBefore();
  },
));

keyDefinitions.registerAction(new Action(
  'join-line',
  'Join current line with line below',
  async function({ session }) {
    await session.joinAtCursor();
  },
));

keyDefinitions.registerAction(new Action(
  'split-line',
  'Split line at cursor',
  async function({ session }) {
    await session.newLineAtCursor();
  },
));

keyDefinitions.registerAction(new Action(
  'scroll-down',
  'Scroll half window down',
  async function({ session }) {
    await session.scroll(0.5);
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'scroll-up',
  'Scroll half window up',
  async function({ session }) {
    await session.scroll(-0.5);
  },
  { sequence: SequenceAction.DROP },
));

// for everything but normal mode
keyDefinitions.registerAction(new Action(
  'exit-mode',
  'Exit back to normal mode',
  async function({ session }) {
    await session.setMode('NORMAL');
  },
  // generally dont repeat actions not in normal mode
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'enter-visual-mode',
  'Enter visual mode',
  async function({ session }) {
    await session.setMode('VISUAL');
  },
));

keyDefinitions.registerAction(new Action(
  'enter-visual-line-mode',
  'Enter visual line mode',
  async function({ session }) {
    await session.setMode('VISUAL_LINE');
  },
));

keyDefinitions.registerAction(new Action(
  'swap-visual-cursor',
  'Swap cursor to other end of selection, in visual and visual line mode',
  async function({ session }) {
    const tmp = session.anchor.clone();
    await session.anchor.from(session.cursor);
    await session.cursor.from(tmp);
  },
));

keyDefinitions.registerAction(new Action(
  'swap-case',
  'Swap case',
  async function({ session }) {
    await session.swapCaseAtCursor();
  },
));

keyDefinitions.registerAction(new Action(
  'visual-swap-case',
  'Swap case in VISUAL mode',
  async function({ session }) {
    await session.swapCaseInVisual(session.cursor, session.anchor);
    await session.setMode('NORMAL');
  },
));

keyDefinitions.registerAction(new Action(
  'visual-line-swap-case',
  'Swap case in VISUAL_LINE mode',
  async function({ session, visual_line }: ActionContext) {
    if (visual_line == null) {
      throw new Error('Visual_line mode arguments missing');
    }

    const rows = (await session.document.getChildRange(
      visual_line.parent, visual_line.start_i, visual_line.end_i
    )).map(path => {
      return path.row;
    });

    await session.swapCaseInVisualLine(rows);
    await session.setMode('NORMAL');
  },
));
