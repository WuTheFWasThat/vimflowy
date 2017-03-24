import $ from 'jquery';

import keyDefinitions, { Motion } from '../keyDefinitions';
import Path from '../path';
import { Col } from '../types';

// TODO: make this work in visual line and add to SINGLE_LINE_MOTIONS
// TODO: have a cursorOption whether to stay within line
//
keyDefinitions.registerMotion(new Motion(
  'motion-display-up',
  'Move cursor up by displayed lines',
  async function({ session }) {
    return async (cursor, options) => {
      const cursorDivs = $(`[data-column='${cursor.col}'][data-path='${cursor.path.getAncestry().join(',')}']`);
      if (cursorDivs.length === 0) {
        session.showMessage('Error: could not find cursor div', { text_class: 'error' });
        return;
      } else if (cursorDivs.length > 1) {
        session.showMessage('Warning: Possible bug. Multiple cursor divs found', { text_class: 'error' });
      }
      const index = cursorDivs.index() - 1;
      let siblings = cursorDivs.siblings().get();
      const cursorOffset = cursorDivs.offset();

      let candidate: null | [Path, Col, { left: number, top: number} ] = null;

      for (let i = 0; i < index; i++) {
        const sibling = $(siblings[i]);
        const offset = sibling.offset();
        if (offset.top === cursorOffset.top) {
          continue; // same row, not valid
        }
        if (offset.top > cursorOffset.top) {
          session.showMessage('Warning: Possible bug. Earlier div was lower on page?', { text_class: 'error' });
          continue;
        }
        const col: Col = parseInt(sibling.data('column'), 10);
        if (col === NaN) { continue; }
        let stringpath = sibling.data('path');
        if (!stringpath) { continue; }
        const path: Path = Path.loadFromAncestry(stringpath.split(',').map((x: string) => parseInt(x, 10)));
        if (candidate == null) { // no current candidate
          candidate = [path, col, offset];
          continue;
        }
        const curOffset = candidate[2];
        if (Math.abs(curOffset.top - cursorOffset.top) < Math.abs(offset.top - cursorOffset.top)) {
          continue; // not the closest row
        }
        if (Math.abs(curOffset.left - cursorOffset.left) < Math.abs(offset.left - cursorOffset.left)) {
          continue; // not the closest column
        }
        // we are the closest column in the closest row
        candidate = [path, col, offset];
      }

      if (candidate == null) {
        await cursor.up(options);
      } else {
        const newPath: Path = candidate[0];
        const newCol: Col = candidate[1];
        await cursor.setPosition(newPath, newCol, options);
      }
    };
  },
));

keyDefinitions.registerMotion(new Motion(
  'motion-display-down',
  'Move cursor down by displayed lines',
  async function({ session }) {
    return async (cursor, options) => {
      const cursorDivs = $(`[data-column='${cursor.col}'][data-path='${cursor.path.getAncestry().join(',')}']`);
      if (cursorDivs.length === 0) {
        session.showMessage('Error: could not find cursor div', { text_class: 'error' });
        return;
      } else if (cursorDivs.length > 1) {
        session.showMessage('Warning: Possible bug. Multiple cursor divs found', { text_class: 'error' });
      }
      const index = cursorDivs.index() - 1;
      let siblings = cursorDivs.siblings().get();
      const cursorOffset = cursorDivs.offset();

      let candidate: null | [Path, Col, { left: number, top: number} ] = null;

      for (let i = index + 1; i < siblings.length; i++) {
        const sibling = $(siblings[i]);
        const offset = sibling.offset();
        if (offset.top === cursorOffset.top) {
          continue; // same row, not valid
        }
        if (offset.top < cursorOffset.top) {
          session.showMessage('Warning: Possible bug. Later div was higher on page?', { text_class: 'error' });
          continue;
        }
        const col: Col = parseInt(sibling.data('column'), 10);
        if (col === NaN) { continue; }
        let stringpath = sibling.data('path');
        if (!stringpath) { continue; }
        const path: Path = Path.loadFromAncestry(stringpath.split(',').map((x: string) => parseInt(x, 10)));
        if (candidate == null) { // no current candidate
          candidate = [path, col, offset];
          continue;
        }
        const curOffset = candidate[2];
        if (Math.abs(curOffset.top - cursorOffset.top) < Math.abs(offset.top - cursorOffset.top)) {
          continue; // not the closest row
        }
        if (Math.abs(curOffset.left - cursorOffset.left) < Math.abs(offset.left - cursorOffset.left)) {
          continue; // not the closest column
        }
        // we are the closest column in the closest row
        candidate = [path, col, offset];
      }

      if (candidate == null) {
        await cursor.down(options);
      } else {
        const newPath: Path = candidate[0];
        const newCol: Col = candidate[1];
        await cursor.setPosition(newPath, newCol, options);
      }
    };
  },
));
