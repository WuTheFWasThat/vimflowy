import * as React from 'react';
import * as _ from 'lodash';

import * as constants from '../constants';
import * as utils from '../utils';
import { Col, Line } from '../types';

type WordInfo = any; // TODO
type RenderOptions = {
  cursor?: boolean;
  highlight?: boolean;
  text?: string;
  type?: string;
  href?: string;
  onClick?: (e: Event) => void;
  classes?: Array<string>;
}
type LineInfo = {
  column: number,
  char: string,
  break: boolean,
  renderOptions: RenderOptions,
};

export type LineProps = {
  lineData: Line;
  cursors?: {[key: number]: boolean};
  highlights?: {[key: number]: boolean};
  wordHook?: (line: Array<LineInfo>, word_info: WordInfo) => Array<LineInfo>;
  onCharClick?: ((col: Col, e: Event) => void) | null;
  cursorBetween?: boolean;
}

export default class LineComponent extends React.Component<LineProps, {}> {

  constructor(props) {
    super(props);
  }

  public shouldComponentUpdate(nextProps) {
    if (nextProps.lineData !== this.props.lineData) {
      return true;
    }
    if (this.props.cursors && Object.keys(this.props.cursors).length > 0) {
      return true;
    }
    if (nextProps.cursors && Object.keys(nextProps.cursors).length > 0) {
      return true;
    }
    if (this.props.highlights && Object.keys(this.props.highlights).length > 0) {
      return true;
    }
    if (nextProps.highlights && Object.keys(nextProps.highlights).length > 0) {
      return true;
    }
    if (nextProps.cursorBetween !== this.props.cursorBetween) {
      return true;
    }
    if (nextProps.onCharClick !== this.props.onCharClick) {
      return true;
    }
    // NOTE: technically, we are ignoring wordHook changing

    return true;
  }

  public render() {
    const lineData = _.cloneDeep(this.props.lineData);
    const cursors = this.props.cursors || {};
    const highlights = this.props.highlights || {};

    const results: Array<React.ReactNode> = [];

    // ideally this takes up space but is unselectable (uncopyable)
    const cursorChar = ' ';

    let line: Array<LineInfo> = [];

    // add cursor if at end
    // NOTE: this doesn't seem to work for the breadcrumbs, e.g. try visual selecting word at end
    if (lineData.length in cursors) {
      lineData.push({char: cursorChar});
    }

    if (lineData.length === 0) {
      return <span></span>;
    }

    for (let i = 0; i < lineData.length; i++) {
      const obj = lineData[i];
      const renderOptions: RenderOptions = {};

      constants.text_properties.forEach((property) => {
        if (obj[property]) {
          renderOptions[property] = true;
        }
      });

      let x = obj.char;

      let isBreak = false;
      if (obj.char === '\n') {
        // tricky logic for rendering new lines within a bullet
        // (copies correctly, works when cursor is on the newline itself)
        x = '';
        isBreak = true;
        if (i in cursors) {
          x = cursorChar + x;
        }
      }

      if (i in cursors) {
        renderOptions.cursor = true;
      } else if (i in highlights) {
        renderOptions.highlight = true;
      }

      const info: LineInfo = {
        column: i,
        char: x,
        break: isBreak,
        renderOptions: renderOptions,
      };

      line.push(info);
    }

    // collect set of words, { word: word, start: start, end: end }
    let word_chars: Array<string> = [];
    let word_start = 0;


    const newLineData = lineData.concat([{char: ' '}]);
    for (let i = 0; i < newLineData.length; i++) { // to make end condition easier
      // TODO  or (utils.isPunctuation obj.char)
      // problem is URLs have dots in them...
      const obj = newLineData[i];
      if (utils.isWhitespace(obj.char)) {
        if (i !== word_start) {
          const word_info = {
            word: word_chars.join(''),
            start: word_start,
            end: i - 1,
          };
          if (this.props.wordHook) {
            line = this.props.wordHook(line, word_info);
          }
          if (utils.isLink(word_info.word)) {
            for (let j = word_info.start; j <= word_info.end; j++) {
              line[j].renderOptions.type = 'a';
              line[j].renderOptions.href = word_info.word;
            }
          }
        }
        word_start = i + 1;
        word_chars = [];
      } else {
        word_chars.push(obj.char);
      }
    }

    const renderSpec: Array<RenderOptions> = [];
    // Normally, we collect things of the same type and render them in one div
    // If there are column-specific handlers, however, we must break up the div to handle
    // separate click events
    if (this.props.onCharClick) {
      line.forEach((x) => {
        x.renderOptions.text = x.char;
        if ((!x.renderOptions.href) && (!x.renderOptions.onClick) && this.props.onCharClick) {
          x.renderOptions.onClick = this.props.onCharClick.bind(this, x.column);
        }
        renderSpec.push(x.renderOptions);
        if (x.break) {
          renderSpec.push({type: 'div'});
        }
      });
    } else {
      let acc: Array<string> = [];
      let renderOptions: RenderOptions = {};

      const flush = function() {
        if (acc.length) {
          renderOptions.text = acc.join('');
          renderSpec.push(renderOptions);
          acc = [];
        }
        renderOptions = {};
      };

      // collect line into groups to render
      line.forEach((x) => {
        if (JSON.stringify(x.renderOptions) === JSON.stringify(renderOptions)) {
          acc.push(x.char);
        } else {
          flush();
          acc.push(x.char);
          ({ renderOptions } = x);
        }

        if (x.break) {
          flush();
          renderSpec.push({type: 'div'});
        }
      });
      flush();
    }

    renderSpec.forEach((spec, index) => {
      const classes = spec.classes || [];
      const divType = spec.type || 'span';
      if (divType === 'a') {
        classes.push('theme-text-link');
      }

      // make sure .bold, .italic, .strikethrough, .underline correspond to the text properties
      constants.text_properties.forEach((property) => {
        if (spec[property]) {
          classes.push(property);
        }
      });

      if (spec.cursor) {
        if (this.props.cursorBetween) {
          results.push(
            <div key='insert-cursor'
              className='theme-cursor blink-background'
              style={{
                display: 'inline-block',
                height: '1.2em', width: 2, marginLeft: -1, marginRight: -1,
              }}>
              {' '}
            </div>
          );
        } else {
          classes.push('cursor', 'theme-cursor');
        }
      }
      if (spec.highlight) {
        classes.push('theme-bg-highlight');
      }

      results.push(
        React.createElement(
          divType,
          {
            key: index,
            className: classes.join(' '),
            href: spec.href,
            onClick: spec.onClick,
          } as React.DOMAttributes<any>,
          spec.text as React.ReactNode
        )
      );
    });

    return (
      <span>
        {results}
      </span>
    );
  }
}
