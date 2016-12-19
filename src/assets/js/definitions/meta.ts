import keyDefinitions, { Action, SequenceAction } from '../keyDefinitions';

keyDefinitions.registerAction(new Action(
  'export-file',
  'Export as Json file',
  async function() {
    await this.session.exportFile('json');
  },
  {
    sequence: SequenceAction.DROP,
  },
));

