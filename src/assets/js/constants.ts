import { SerializedBlock } from './types';

type TextProperty = 'bold' | 'italic' | 'underline' | 'strikethrough';
export const text_properties: Array<TextProperty> = ['bold', 'italic', 'underline', 'strikethrough'];

export const empty_data = [''];
export const default_data: Array<SerializedBlock> = [
  'Welcome to vimflowy!',
  'I hope you know to use j and k to move up and down!  If not, the cheat sheet on the right will be your friend',
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
          text:      'Bold, italicized, and underlined text.  Emphatic!',
          bold:      '....                                    ........ ',
          italic:    '      ..........                        ........ ',
          underline: '                      ..........        ........ ',
        },
        {
          text:          'Strike through',
          children: [ {
            text:          'Useful for todo lists',
            strikethrough: '.....................',
          } ],
        },
      ] },
    ] },
    { text: 'Vim features', collapsed: true, children: [
      'Most of vim\'s movement commands',
      'Modal editing (note visual mode only works on one line)',
      'Undo/redo, repeat, and macros',
      'Let the vimflowy devs know if anything major is missing',
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
