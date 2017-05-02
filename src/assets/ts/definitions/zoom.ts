import keyDefinitions, { Action, SequenceAction } from '../keyDefinitions';

keyDefinitions.registerAction(new Action(
  'zoom-prev-sibling',
  'Zoom to view root\'s previous sibling',
  async function({ session }) {
    await session.zoomUp();
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'zoom-next-sibling',
  'Zoom to view root\'s next sibling',
  async function({ session }) {
    await session.zoomDown();
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'zoom-in',
  'Zoom in by one level',
  async function({ session }) {
    await session.zoomIn();
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'zoom-out',
  'Zoom out by one level',
  async function({ session }) {
    await session.zoomOut();
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'zoom-cursor',
  'Zoom in onto cursor',
  async function({ session }) {
    await session.zoomInto(session.cursor.path);
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'zoom-root',
  'Zoom out to document root',
  async function({ session }) {
    await session.zoomInto(session.document.root);
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'jump-prev',
  'Jump to previously visited location',
  async function({ session }) {
    await session.jumpPrevious();
  },
  { sequence: SequenceAction.DROP },
));

keyDefinitions.registerAction(new Action(
  'jump-next',
  'Jump to next location',
  async function({ session }) {
    await session.jumpNext();
  },
  { sequence: SequenceAction.DROP },
));
