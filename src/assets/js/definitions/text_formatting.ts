import keyDefinitions, { Action, ActionContext } from '../keyDefinitions';

const toggle_row_property = (property) => {
  return async function({ session }) {
    await session.toggleRowProperty(property);
  };
};

const toggle_property_at_cursor = (property) => {
  return async function({ session }) {
    session.cursor.toggleProperty(property);
  };
};

const toggle_property_visual_line = property =>
  async function({ session, visual_line }: ActionContext) {
    if (visual_line == null) {
      throw new Error('Visual_line mode arguments missing');
    }
    const rows = (await session.document.getChildRange(
      visual_line.parent, visual_line.start_i, visual_line.end_i
    )).map(path => {
      return path.row;
    });
    await session.toggleRowsProperty(property, rows);
    await session.setMode('NORMAL');
  }
;

const toggle_property_visual = property =>
  async function({ session }) {
    await session.toggleRowPropertyBetween(property, session.cursor, session.anchor, {includeEnd: true});
    await session.setMode('NORMAL');
  }
;

keyDefinitions.registerAction(new Action(
  'toggle-row-bold',
  'Bold text',
  toggle_row_property('bold')
));
keyDefinitions.registerAction(new Action(
  'toggle-cursor-bold',
  'Bold text',
  toggle_property_at_cursor('bold')
));
keyDefinitions.registerAction(new Action(
  'visual-toggle-bold',
  'Bold text',
  toggle_property_visual('bold')
));
keyDefinitions.registerAction(new Action(
  'visual-line-toggle-bold',
  'Bold text',
  toggle_property_visual_line('bold')
));
keyDefinitions.registerAction(new Action(
  'toggle-row-italic',
  'Italicize text',
  toggle_row_property('italic')
));
keyDefinitions.registerAction(new Action(
  'toggle-cursor-italic',
  'Italicize text',
  toggle_property_at_cursor('italic')
));
keyDefinitions.registerAction(new Action(
  'visual-toggle-italic',
  'Italicize text',
  toggle_property_visual('italic')
));
keyDefinitions.registerAction(new Action(
  'visual-line-toggle-italic',
  'Italicize text',
  toggle_property_visual_line('italic')
));
keyDefinitions.registerAction(new Action(
  'toggle-row-underline',
  'Underline text',
  toggle_row_property('underline')
));
keyDefinitions.registerAction(new Action(
  'toggle-cursor-underline',
  'Underline text',
  toggle_property_at_cursor('underline')
));
keyDefinitions.registerAction(new Action(
  'visual-toggle-underline',
  'Underline text',
  toggle_property_visual('underline')
));
keyDefinitions.registerAction(new Action(
  'visual-line-toggle-underline',
  'Underline text',
  toggle_property_visual_line('underline')
));
keyDefinitions.registerAction(new Action(
  'toggle-row-strikethrough',
  'Strike through text',
  toggle_row_property('strikethrough')
));
keyDefinitions.registerAction(new Action(
  'toggle-cursor-strikethrough',
  'Strike through text',
  toggle_property_at_cursor('strikethrough')
));
keyDefinitions.registerAction(new Action(
  'visual-toggle-strikethrough',
  'Strike through text',
  toggle_property_visual('strikethrough')
));
keyDefinitions.registerAction(new Action(
  'visual-line-toggle-strikethrough',
  'Strike through text',
  toggle_property_visual_line('strikethrough')
));
