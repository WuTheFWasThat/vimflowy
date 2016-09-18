// tslint:disable:align

import * as Modes from '../modes';
import keyDefinitions from '../keyDefinitions';

const MODES = Modes.modes;

const CMD_EXPORT = keyDefinitions.registerCommand({
  name: 'EXPORT',
  default_hotkeys: {
    normal_like: ['ctrl+s'],
    insert_like: ['ctrl+s'],
  },
});
keyDefinitions.registerAction([MODES.NORMAL, MODES.INSERT], CMD_EXPORT, {
  description: 'Export as Json file',
}, async function() {
  await this.session.exportFile('json');
});

