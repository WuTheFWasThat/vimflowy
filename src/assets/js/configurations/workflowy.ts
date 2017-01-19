import * as _ from 'lodash';

import { SerializedBlock } from '../types';
import KeyMappings, { HotkeyMapping } from '../keyMappings';
import { motionKey } from '../keyDefinitions';
import { SINGLE_LINE_MOTIONS } from '../definitions/motions';
import Config from '../config';

export const INSERT_MOTION_MAPPINGS: HotkeyMapping = {
  'motion-left': [['left']],
  'motion-right': [['right']],
  'motion-up': [['up']],
  'motion-down': [['down']],
  'motion-line-beginning': [['home'], ['ctrl+a'], ['meta+left']],
  'motion-line-end': [['end'], ['ctrl+e'], ['meta+right']],
  'motion-word-beginning': [['alt+b'], ['alt+left']],
  'motion-word-end': [],
  'motion-word-next': [['alt+f'], ['alt+right']],
  'motion-Word-beginning': [],
  'motion-Word-end': [],
  'motion-Word-next': [],

  'motion-visible-beginning': [['meta+home']],
  'motion-visible-end': [['meta+end']],
  'motion-parent': [['ctrl+g', 'p']],
  'motion-next-clone': [['ctrl+g', 'c']],
  'motion-next-sibling': [['alt+down']],
  'motion-prev-sibling': [['alt+up']],
};

export const INSERT_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-insert': [[motionKey]],
  'toggle-help': [['ctrl+?'], ['meta+?']],
  'fold-toggle': [],
  'fold-open': [['meta+down']],
  'fold-close': [['meta+up']],
  'delete-blocks': [['meta+shift+delete'], ['meta+backspace']],
  'delete-char-after': [['delete']],
  'delete-char-before': [['backspace'], ['shift+backspace']],
  'delete-to-line-beginning': [['ctrl+u']],
  'delete-to-line-end': [['ctrl+k']],
  'delete-to-word-beginning': [['alt+delete']],
  // NOTE: paste-after doesn't make much sense for insert mode
  'paste-before': [['ctrl+y']],
  'split-line': [['enter']],
  'scroll-down': [['page down']],
  'scroll-up': [['page up']],
  'undo': [['ctrl+z'], ['meta+z']],
  'redo': [['ctrl+Z'], ['meta+Z'], ['meta+y']],
  'unindent-row': [],
  'indent-row': [],
  'unindent-blocks': [['shift+tab']],
  'indent-blocks': [['tab']],
  'search': [['esc', 'ctrl+f']],
  'swap-block-down': [['meta+shift+up']],
  'swap-block-up': [['meta+shift+down']],
  'toggle-cursor-bold': [['meta+b']],
  'toggle-cursor-italic': [['meta+i']],
  'toggle-cursor-underline': [['meta+u']],
  // NOTE: in workflowy, this also crosses out children
  'toggle-cursor-strikethrough': [['meta+enter']],
  'zoom-prev-sibling': [],
  'zoom-next-sibling': [],
  'zoom-in': [],
  'zoom-out': [['meta+<']],
  'zoom-cursor': [['meta+>']],
  'zoom-root': [],
}, INSERT_MOTION_MAPPINGS);

export const SEARCH_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-search': [[motionKey]],
  'toggle-help': [['ctrl+?']],
  'exit-mode': [['esc'], ['ctrl+c']],
  'search-delete-char-after': [['delete']],
  'search-delete-char-before': [['backspace'], ['shift+backspace']],
  'search-select': [['enter']],
  'search-up': [['ctrl+k'], ['up'], ['shift+tab']],
  'search-down': [['ctrl+j'], ['down'], ['tab']],
}, _.pick(INSERT_MOTION_MAPPINGS, SINGLE_LINE_MOTIONS));

export const SETTINGS_MODE_MAPPINGS: HotkeyMapping = {
  'exit-mode': [['esc'], ['ctrl+c']],
};

// TODO fix this
const defaultData: Array<SerializedBlock> = [
  'Welcome to vimflowy!',
  { text: 'Features', children: [
    { text: 'Workflowy features', children: [
      { text: 'Nested bullets', children: [
        'Bullets with children can be collapsed',
        { text: 'Use enter to zoom into any bullet.  Try on this one', collapsed: true, children: [
          'And shift+enter to zoom all the way back out',
          'Use ] and [ to zoom in and out just one level',
        ] },
        { text: 'Use z to toggle collapsedness', collapsed: true, children: [
          'You found me :)',
        ] },
        'Use tab and shift+tab to indent and unindent blocks',
        'Use < and > to indent and unindent just a single line',
      ] },
      { text: 'Text formatting', collapsed: true, children: [
        {
          text:        'Bold, italicized, and underlined text.  Emphatic!',
          properties: {
            bold:      '....                                    ........ ',
            italic:    '      ..........                        ........ ',
            underline: '                      ..........        ........ ',
          },
        },
        {
          text:          'Strike through',
          children: [ {
            text:            'Useful for todo lists',
            properties: {
              strikethrough: '.....................',
            },
          } ],
        },
      ] },
    ] },
    'Press / to start searching for text',
    { text: 'Marks', plugins: { mark: 'mark' }, collapsed: true, children: [
      { text: 'I am marked!', plugins: { mark: 'im_a_mark' } },
      'Press m to start marking a line, and enter to finish',
      'Use \' to search and jump to marks',
      'Link to marks with the @ symbol, like this:  @im_a_mark.  Use gm to follow the link.',
      'Delete marks by using dm, or just mark with empty string',
    ] },
    { text: 'Cloning', collapsed: true, children: [
      { text: 'I am a clone!  Try editing me', id: 1 },
      { text: 'Clones can\'t be siblings or descendants of each other', children: [
        { clone: 1 },
      ] },
      'Make new clones with yc, then p',
    ] },
    { text: 'Customizability', collapsed: true, children: [
      { text: 'Plugins system', collapsed: true, children: [
        'See the settings menu to turn on some plugins!',
        'If you\'re interested in writing plugins, see here: ' +
        'https://github.com/WuTheFWasThat/vimflowy/blob/master/docs/plugins.md',
      ] },
      'Customizable hotkeys (via downloading/uploading a json file)',
      'Different color themes (see Settings)',
    ] },
  ] },
  { text: 'Data', collapsed: true, children: [
    { text: 'Backing storage', children: [
      'Vimflowy was designed to be agnostic to the storage backend',
      'As a user, you are in full control of your data',
      'By default, all data is entirely local',
      'There are no backups, and it is never sent over the internet',
      'However, remote data storage is supported',
      'To manage your data, visit the Settings menu',
    ] },
    { text: 'Importing and exporting data', children: [
      'Two import and export formats are supported.',
      'Check out settings for more information.',
      'You can regularly export your data in JSON format, as a form of backup',
    ] },
  ] },
  { text: 'Tips', collapsed: true, children: [
    'Collapse things often to avoid clutter.  Zoom into collapsed bullets',
    'Want to go back to where you were?  ctrl+o jumps back in your location history (ctrl+i jumps forward)',
    'Check out the cheat sheet on the right.  Once you become an expert, you can hide it',
  ] },
  'Press i to enter insert mode and start adding your own content!',
  'For more info, visit https://github.com/WuTheFWasThat/vimflowy (visit links under the cursor with gx)',
];

const config: Config = {
  type: 'workflowy',
  defaultMode: 'INSERT',
  defaultData: defaultData,
  // TODO: get the keys from modes.ts
  defaultMappings:
    new KeyMappings({
      [ 'INSERT' ]: INSERT_MODE_MAPPINGS,
      [ 'SEARCH' ]: SEARCH_MODE_MAPPINGS,
      [ 'SETTINGS' ]: SETTINGS_MODE_MAPPINGS,
    }),
};
export default config;
