import * as _ from 'lodash';

import { SerializedBlock } from '../types';
import KeyMappings, { HotkeyMapping } from '../keyMappings';
import { motionKey } from '../keyDefinitions';
import { SINGLE_LINE_MOTIONS } from '../definitions/motions';
import Config from '../config';

// TODO: 'next-sentence': [[')']]
// TODO: 'prev-sentence': [['(']]

export const NORMAL_MOTION_MAPPINGS: HotkeyMapping = {
  'motion-left': [['left'], ['h']],
  'motion-right': [['right'], ['l']],
  'motion-up': [['up'], ['k']],
  'motion-down': [['down'], ['j']],
  'motion-line-beginning': [['home'], ['0'], ['^']],
  'motion-line-end': [['end'], ['$']],
  'motion-word-beginning': [['b']],
  'motion-word-end': [['e']],
  'motion-word-next': [['w']],
  'motion-Word-beginning': [['B']],
  'motion-Word-end': [['E']],
  'motion-Word-next': [['W']],

  'motion-visible-beginning': [['g', 'g']],
  'motion-visible-end': [['G'], ['g', 'G']],
  'motion-parent': [['g', 'p']],
  'motion-next-sibling': [['}']],
  'motion-prev-sibling': [['{']],
  // NOTE: should these work in insert mode also?
  'motion-find-next-char': [['f']],
  'motion-find-prev-char': [['F']],
  'motion-to-next-char': [['t']],
  'motion-to-prev-char': [['T']],
};

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
  'motion-next-sibling': [['alt+down']],
  'motion-prev-sibling': [['alt+up']],
};

export const NORMAL_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-normal': [[motionKey]],
  'toggle-help': [['?']],
  'enter-visual-mode': [['v']],
  'enter-visual-line-mode': [['V']],
  'enter-insert-before-cursor': [['i']],
  'enter-insert-after-cursor': [['a']],
  'enter-insert-line-beginning': [['I']],
  'enter-insert-line-end': [['A']],
  'enter-insert-below-line': [['o']],
  'enter-insert-above-line': [['O']],
  'visit-link': [['g', 'x']],
  'fold-toggle': [['z']],
  'fold-open': [],
  'fold-close': [],
  'replace-char': [['r']],
  'delete-blocks': [['d', 'd']],
  'delete-motion': [['d', motionKey]],
  'change-line': [['c', 'c']],
  'change-to-line-end': [['C']],
  'change-blocks': [['c', 'r']],
  'change-motion': [['c', motionKey]],
  'yank-line': [['y', 'y']],
  'yank-to-line-end': [['Y']],
  'yank-blocks': [['y', 'r']],
  'yank-motion': [['y', motionKey]],
  'yank-clone': [['y', 'c']],
  'normal-delete-char': [['x']],
  'normal-delete-char-before': [['X']],
  'change-char': [['s']],
  'delete-to-line-beginning': [],
  'delete-to-line-end': [['D']],
  'delete-to-word-beginning': [],
  'paste-after': [['p']],
  'paste-before': [['P']],
  'join-line': [['J']],
  'split-line': [['K']],
  'scroll-down': [['page down'], ['ctrl+d']],
  'scroll-up': [['page up'], ['ctrl+u']],
  'undo': [['u']],
  'redo': [['ctrl+r']],
  'replay-command': [['.']],
  'record-macro': [['q']],
  'play-macro': [['@']],
  'unindent-row': [['<']],
  'indent-row': [['>']],
  'unindent-blocks': [['shift+tab'], ['ctrl+h']],
  'indent-blocks': [['tab'], ['ctrl+l']],
  'swap-block-down': [['ctrl+j']],
  'swap-block-up': [['ctrl+k']],
  'search-local': [['ctrl+/'], ['ctrl+f']],
  'search-global': [['/']],
  'export-file': [['ctrl+s']],
  'zoom-prev-sibling': [['alt+k']],
  'zoom-next-sibling': [['alt+j']],
  'zoom-in': [[']'], ['alt+l'], ['ctrl+right']],
  'zoom-out': [['['], ['alt+h'], ['ctrl+left']],
  'zoom-cursor': [['enter'], ['ctrl+shift+right']],
  'zoom-root': [['shift+enter'], ['ctrl+shift+left']],
  'jump-prev': [['ctrl+o']],
  'jump-next': [['ctrl+i']],
  'swap-case': [['~']],
  'go-next-clone': [['g', 'c']],
}, NORMAL_MOTION_MAPPINGS);

export const VISUAL_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-visual': [[motionKey]],
  'toggle-help': [['?']],
  'exit-mode': [['esc'], ['ctrl+c'], ['ctrl+[']],
  'swap-visual-cursor': [['o'], ['O']],
  'visual-delete': [['d'], ['x']],
  'visual-change': [['c']],
  'visual-yank': [['y']],
  'visual-swap-case': [['~']],
}, _.pick(NORMAL_MOTION_MAPPINGS, SINGLE_LINE_MOTIONS));

export const VISUAL_LINE_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-visual-line': [[motionKey]],
  'toggle-help': [['?']],
  'exit-mode': [['esc'], ['ctrl+c'], ['ctrl+[']],
  'swap-visual-cursor': [['o'], ['O']],
  'visual-line-delete': [['d'], ['x']],
  'visual-line-change': [['c']],
  'visual-line-yank': [['y']],
  'visual-line-yank-clone': [['Y']],
  'visual-line-indent': [['>'], ['tab'], ['ctrl+l']],
  'visual-line-unindent': [['<'], ['shift+tab'], ['ctrl+h']],
  'visual-line-swap-case': [['~']],
}, NORMAL_MOTION_MAPPINGS);

export const INSERT_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-insert': [[motionKey]],
  'toggle-help': [['ctrl+?']],
  'exit-mode': [['esc'], ['ctrl+c'], ['ctrl+[']],
  'fold-toggle': [['ctrl+space']],
  'fold-open': [['meta+down']],
  'fold-close': [['meta+up']],
  'delete-blocks': [['meta+shift+delete']],
  'delete-char-after': [['delete']],
  'delete-char-before': [['backspace'], ['shift+backspace']],
  'delete-to-line-beginning': [['ctrl+u']],
  'delete-to-line-end': [['ctrl+k']],
  'delete-to-word-beginning': [['ctrl+w'], ['ctrl+backspace']],
  // NOTE: paste-after doesn't make much sense for insert mode
  'paste-before': [['ctrl+y']],
  'split-line': [['enter']],
  'scroll-down': [['page down']],
  'scroll-up': [['page up']],
  'undo': [['ctrl+z']],
  'redo': [['ctrl+Z']],
  'unindent-row': [],
  'indent-row': [],
  'unindent-blocks': [['shift+tab']],
  'indent-blocks': [['tab']],
  'swap-block-down': [],
  'swap-block-up': [],
  'zoom-prev-sibling': [['alt+k']],
  'zoom-next-sibling': [['alt+j']],
  'zoom-in': [['ctrl+right']],
  'zoom-out': [['ctrl+left']],
  'zoom-cursor': [['ctrl+shift+right']],
  'zoom-root': [['ctrl+shift+left']],
}, INSERT_MOTION_MAPPINGS);

export const SEARCH_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-search': [[motionKey]],
  'toggle-help': [['ctrl+?']],
  'exit-mode': [['esc'], ['ctrl+c'], ['ctrl+[']],
  'search-delete-char-after': [['delete']],
  'search-delete-char-before': [['backspace'], ['shift+backspace']],
  'search-select': [['enter']],
  'search-up': [['ctrl+k'], ['up'], ['shift+tab']],
  'search-down': [['ctrl+j'], ['down'], ['tab']],
}, _.pick(INSERT_MOTION_MAPPINGS, SINGLE_LINE_MOTIONS));

export const SETTINGS_MODE_MAPPINGS: HotkeyMapping = {
  'exit-mode': [['esc'], ['ctrl+c'], ['ctrl+[']],
};

export const WORKFLOWY_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-insert': [[motionKey]],
  'toggle-help': [['ctrl+?'], ['meta+?']],
  'fold-toggle': [],
  'fold-open': [['meta+down']],
  'fold-close': [['meta+up']],
  'delete-blocks': [['meta+shift+delete']],
  'delete-char-after': [['delete']],
  'delete-char-before': [['backspace'], ['shift+backspace']],
  'delete-to-line-beginning': [['ctrl+u']],
  'delete-to-line-end': [['ctrl+k']],
  'delete-to-word-beginning': [['ctrl+w'], ['ctrl+backspace']],
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
  'swap-block-down': [['meta+shift+up']],
  'swap-block-up': [['meta+shift+down']],
  'zoom-prev-sibling': [],
  'zoom-next-sibling': [],
  'zoom-in': [],
  'zoom-out': [['meta+<']],
  'zoom-cursor': [['meta+>']],
  'zoom-root': [],
}, INSERT_MOTION_MAPPINGS);

function getDefaultData(): Array<SerializedBlock> {
  return [
    'Welcome to vimflowy!',
    'I hope you know to use j and k to move up and down!',
    'If not, the cheat sheet on the right will be your friend.  Once you become an expert, you\'ll know to use ? to hide it',
    { text: 'Features', children: [
      { text: 'Workflowy features', children: [
        { text: 'Nested bullets', children: [
          'Bullets with children can be collapsed to avoid clutter',
          { text: 'Use enter to zoom into any bullet.  Try on this one', collapsed: true, children: [
            'This bullet had children, but you can zoom into bullets with no children to start expanding upon them',
            'Use shift+enter to zoom all the way back out',
            'Use ] and [ to zoom in and out just one level',
          ] },
          { text: 'Use z to toggle collapsedness', collapsed: true, children: [
            'You found me :)',
          ] },
          'Use tab and shift+tab to indent and unindent blocks',
          'Use < and > to indent and unindent just a single line',
        ] },
      ] },
      { text: 'Vim features', collapsed: true, children: [
        'Most of vim\'s movement commands',
        'Modal editing (note visual mode only works on one line)',
        'Undo/redo, jump history (ctrl+o to jump to previous location, ctrl+i to jump forward)',
        'Repeat commands with . and record macros with q',
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
      { text: 'Rich text', collapsed: true, children: [
        { text: 'Text formatting', collapsed: true, children: [
          '**Bold**, *italicized*, and _underlined_ text.  ** * _Emphatic_ * **!',
          {
            text: 'Strike through',
            children: [
              '~~Cross thing off todo list~~',
              'Cross another thing off todo list',
            ],
          },
        ] },
        { text: 'LaTeX', collapsed: true, children: [
          'Inline equations: $E = mc^2$ and $f(b) - f(a) = \\int_a^b f\'(t) dt$',
          'Block equations: $$\\max_{x \\ge 0, Ax \\le b} c^T x = \\min_{y \\ge 0, A^ty \\ge c} b^T y$$',
        ] },
        { text: 'HTML', collapsed: true, children: [
          'Inline arbitrary HTML, such as images: <img src="/images/vimflowy-32.png"/>',
          'Or tables: <table><tr><th>Pros</th><th>Cons</th></tr><tr><td>Everything</td><td>Nothing</td></tr></table>',
          'Or <span style=\'color: blue\'>colored</span> <span style=\'color: orange\'>text</span>',
        ] },
      ] },
      { text: 'Customizability (see Settings menu)', collapsed: true, children: [
        { text: 'Plugins system', collapsed: true, children: [
          'If you\'re interested in writing plugins, see here: ' +
            'https://github.com/WuTheFWasThat/vimflowy/blob/master/docs/plugins.md',
        ] },
        'Customizable hotkeys (via downloading/uploading a json file)',
        'Customizable color theme',
      ] },
    ] },
    { text: 'Data', collapsed: true, children: [
      { text: 'Backing storage', children: [
        'Vimflowy was designed to be agnostic to the storage backend',
        'As a user, you are in full control of your data',
        'By default, all data is entirely local',
        'There are no backups, and it is never sent over the internet',
        'However, remote data storage is supported',
        'For more details, visit https://github.com/WuTheFWasThat/vimflowy/blob/master/docs/storage/README.md',
        'To manage your data, visit the Settings menu',
      ] },
      { text: 'Importing and exporting data', children: [
        'Two import and export formats are supported.',
        'Check out settings for more information.',
        'You can regularly export your data in JSON format, as a form of backup',
      ] },
      'To make a new document with separate data, just add the "doc" query parameter. ' +
        `For example, ${window.location.origin}/?doc=newdocname#`,
    ] },
    'Press i to enter insert mode and start adding your own content!',
    'For more info, visit https://github.com/WuTheFWasThat/vimflowy (visit links under the cursor with gx)',
  ];
}

const config: Config = {
  defaultMode: 'NORMAL',
  getDefaultData: getDefaultData,
  // TODO: get the keys from modes.ts
  defaultMappings:
    new KeyMappings({
      [ 'NORMAL' ]: NORMAL_MODE_MAPPINGS,
      [ 'INSERT' ]: INSERT_MODE_MAPPINGS,
      [ 'VISUAL' ]: VISUAL_MODE_MAPPINGS,
      [ 'VISUAL_LINE' ]: VISUAL_LINE_MODE_MAPPINGS,
      [ 'SEARCH' ]: SEARCH_MODE_MAPPINGS,
      [ 'SETTINGS' ]: SETTINGS_MODE_MAPPINGS,
    }),
};
export default config;
