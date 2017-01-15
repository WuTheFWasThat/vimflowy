import * as _ from 'lodash';
import logger from './logger';

import EventEmitter from './eventEmitter';
import { motionKey } from './keyDefinitions';
import { Key } from './types';

// TODO: 'swap-case': [['~']]
// TODO: 'next-sentence': [[')']]
// TODO: 'prev-sentence': [['(']]

export type HotkeyMapping = {
  [name: string]: Array<Array<Key>>
};

type HotkeyMappingPerMode = {[mode: string]: HotkeyMapping};

// for each mode, keeps a set of hotkeys
// simple wrapper class, no sanity checks
export class KeyMappings extends EventEmitter {
  public mappings: HotkeyMappingPerMode;

  public static merge(first: KeyMappings, second: KeyMappings) {
    const getMerged = () => {
      const mappings = _.cloneDeep(first.mappings);
      Object.keys(second.mappings).forEach((mode) => {
        mappings[mode] = Object.assign(mappings[mode] || {}, second.mappings[mode]);
      });
      return mappings;
    };
    const merged = new KeyMappings(getMerged());

    first.on('update', () => merged.setMappings(getMerged()));
    second.on('update', () => merged.setMappings(getMerged()));
    return merged;
  }

  constructor(mappings: HotkeyMappingPerMode) {
    super();
    this.mappings = _.cloneDeep(mappings);
  }

  public setMappings(mappings: HotkeyMappingPerMode) {
    this.mappings = mappings;
    this.emit('update');
  }

  public serialize() {
    return _.cloneDeep(this.mappings);
  }

  private _registerMapping(mode: string, keySequence: Array<Key>, name: string) {
    let mappings_for_mode = this.mappings[mode];
    if (!mappings_for_mode) {
      mappings_for_mode = {};
      this.mappings[mode] = mappings_for_mode;
    }
    let sequences_for_name = mappings_for_mode[name];
    if (!sequences_for_name) {
      sequences_for_name = [];
      mappings_for_mode[name] = sequences_for_name;
    }
    sequences_for_name.push(keySequence);
  }

  public registerMapping(mode: string, keySequence: Array<Key>, name: string) {
    this._registerMapping(mode, keySequence, name);
    this.emit('update');
  }

  public registerModeMappings(mode: string, mappings: HotkeyMapping) {
    Object.keys(mappings).forEach((name) => {
      const keySequences = mappings[name];
      keySequences.forEach((sequence) => this._registerMapping(mode, sequence, name));
    });
    this.emit('update');
  }

  // TODO: future dont require name for this
  // also sanity check collisions in registration
  private _deregisterMapping(mode: string, keySequence: Array<Key>, name: string) {
    const mappings_for_mode = this.mappings[mode];
    if (!mappings_for_mode) {
      logger.warn(`Nothing to deregister for mode ${mode}`);
      return;
    }
    let sequences_for_name = mappings_for_mode[name];
    if (!(sequences_for_name && sequences_for_name.length)) {
      logger.warn(`No sequences to deregister for ${name} in mode ${mode}`);
      return;
    }
    sequences_for_name = sequences_for_name.filter((sequence) => {
      return JSON.stringify(sequence) !== JSON.stringify(keySequence);
    });
    mappings_for_mode[name] = sequences_for_name;
  }

  public deregisterMapping(mode: string, keySequence: Array<Key>, name: string) {
    this._deregisterMapping(mode, keySequence, name);
    this.emit('update');
  }

  public deregisterModeMappings(mode: string, mappings: HotkeyMapping) {
    Object.keys(mappings).forEach((name) => {
      const keySequences = mappings[name];
      keySequences.forEach((sequence) => this._deregisterMapping(mode, sequence, name));
    });
    this.emit('update');
  }
}

export const SINGLE_LINE_MOTIONS = [
  'motion-left',
  'motion-right',
  'motion-line-beginning',
  'motion-line-end',
  'motion-word-beginning',
  'motion-word-end',
  'motion-word-next',
  'motion-Word-beginning',
  'motion-Word-end',
  'motion-Word-next',
  'motion-find-next-char',
  'motion-find-prev-char',
  'motion-to-next-char',
  'motion-to-prev-char',
];

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
  'motion-next-clone': [['g', 'c']],
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
  'motion-next-clone': [['ctrl+g', 'c']],
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
  'search': [['/'], ['ctrl+f']],
  'toggle-row-bold': [['ctrl+B']],
  'toggle-row-italic': [['ctrl+I']],
  'toggle-row-underline': [['ctrl+U']],
  'toggle-row-strikethrough': [['ctrl+enter']],
  'export-file': [['ctrl+s']],
  'zoom-prev-sibling': [['alt+k']],
  'zoom-next-sibling': [['alt+j']],
  'zoom-in': [[']'], ['alt+l'], ['ctrl+right']],
  'zoom-out': [['['], ['alt+h'], ['ctrl+left']],
  'zoom-cursor': [['enter'], ['ctrl+shift+right']],
  'zoom-root': [['shift+enter'], ['ctrl+shift+left']],
  'jump-prev': [['ctrl+o']],
  'jump-next': [['ctrl+i']],
}, NORMAL_MOTION_MAPPINGS);

export const VISUAL_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-visual': [[motionKey]],
  'toggle-help': [['?']],
  'exit-mode': [['esc'], ['ctrl+c']],
  'swap-visual-cursor': [['o'], ['O']],
  'visual-delete': [['d'], ['x']],
  'visual-change': [['c']],
  'visual-yank': [['y']],
  'visual-toggle-bold': [['ctrl+B']],
  'visual-toggle-italic': [['ctrl+I']],
  'visual-toggle-underline': [['ctrl+U']],
  'visual-toggle-strikethrough': [['ctrl+enter']],
}, _.pick(NORMAL_MOTION_MAPPINGS, SINGLE_LINE_MOTIONS));

export const VISUAL_LINE_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-visual-line': [[motionKey]],
  'toggle-help': [['?']],
  'exit-mode': [['esc'], ['ctrl+c']],
  'swap-visual-cursor': [['o'], ['O']],
  'visual-line-delete': [['d'], ['x']],
  'visual-line-change': [['c']],
  'visual-line-yank': [['y']],
  'visual-line-yank-clone': [['Y']],
  'visual-line-indent': [['>'], ['tab'], ['ctrl+l']],
  'visual-line-unindent': [['<'], ['shift+tab'], ['ctrl+h']],
  'visual-line-toggle-bold': [['ctrl+B']],
  'visual-line-toggle-italic': [['ctrl+I']],
  'visual-line-toggle-underline': [['ctrl+U']],
  'visual-line-toggle-strikethrough': [['ctrl+enter']],
  'toggle-row-strikethrough': [['meta+enter']],
}, NORMAL_MOTION_MAPPINGS);

export const INSERT_MODE_MAPPINGS: HotkeyMapping = Object.assign({
  'move-cursor-insert': [[motionKey]],
  'toggle-help': [['ctrl+?']],
  'exit-mode': [['esc'], ['ctrl+c']],
  'fold-toggle': [['ctrl+space']],
  'fold-open': [['meta+down']],
  'fold-close': [['meta+up']],
  'delete-blocks': [['meta+shift+delete']],
  'delete-char-after': [['delete']],
  'delete-char-before': [['backspace'], ['shift+backspace']],
  'delete-to-line-beginning': [['ctrl+u']],
  'delete-to-line-end': [['ctrl+k']],
  'delete-to-word-beginning': [['ctrl+w']],
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
  'toggle-cursor-bold': [['ctrl+B']],
  'toggle-cursor-italic': [['ctrl+I']],
  'toggle-cursor-underline': [['ctrl+U']],
  'toggle-cursor-strikethrough': [['ctrl+enter']],
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

// TODO: get the keys from modes.ts
const defaultKeyMappings = new KeyMappings({
  [ 'NORMAL' ]: NORMAL_MODE_MAPPINGS,
  [ 'INSERT' ]: INSERT_MODE_MAPPINGS,
  [ 'VISUAL' ]: VISUAL_MODE_MAPPINGS,
  [ 'VISUAL_LINE' ]: VISUAL_LINE_MODE_MAPPINGS,
  [ 'SEARCH' ]: SEARCH_MODE_MAPPINGS,
  [ 'SETTINGS' ]: SETTINGS_MODE_MAPPINGS,
});
export default defaultKeyMappings;
