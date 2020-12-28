import * as React from 'react';
import * as _ from 'lodash';

import * as text_utils from '../utils/text';
import { Col, Line } from '../types';
import {
  EmitFn, Token, Tokenizer, PartialTokenizer,
  RegexTokenizerSplitter, CharInfo, Unfolder, PartialUnfolder
} from '../utils/token_unfolder';

export type LineProps = {
  lineData: Line;
  cursors?: {[key: number]: boolean};
  cursorStyle: React.CSSProperties;
  highlights?: {[key: number]: boolean};
  highlightStyle: React.CSSProperties;
  accents?: {[key: number]: boolean};
  accentStyle: React.CSSProperties;
  linksStyle: React.CSSProperties;
  lineHook?: PartialUnfolder<Token, React.ReactNode>;
  wordHook?: PartialUnfolder<Token, React.ReactNode>;
  onCharClick?: ((col: Col, e: Event) => void) | undefined;
  cursorBetween?: boolean;
};

// NOTE: hacky! we don't include .:/?= since urls contain it
// should instead make tokenizer for URLs
// also not including @ for marks
const word_boundary_chars = '\t\r\n ,!()\"\'*+\\;<>\\[\\]`{}|';

export default class LineComponent extends React.Component<LineProps, {}> {

  constructor(props: LineProps) {
    super(props);
  }

  public render() {
    const cursorBetween: boolean = this.props.cursorBetween || false;
    const lineData = _.cloneDeep(this.props.lineData);
    const cursors = this.props.cursors || {};
    const highlights = this.props.highlights || {};
    const accents = this.props.accents || {};

    // ideally this takes up space but is unselectable (uncopyable)
    const cursorChar = ' ';

    // add cursor if at end
    if (lineData.length in cursors) {
      lineData.push(cursorChar);
    }

    if (lineData.length === 0) {
      return <span></span>;
    }

    const cursorBetweenDiv = (i: number) => {
      return (
        <div key={`insert-cursor-${i}`}
          className='cursor blink-background'
          style={{
            display: 'inline-block',
            height: '1.2em', width: 2, marginLeft: -1, marginRight: -1,
            ...this.props.cursorStyle,
          }}>
          {' '}
        </div>
      );
    };

    const DefaultTokenizer: Tokenizer = new Unfolder<Token, React.ReactNode>((
      token: Token, emit: EmitFn<React.ReactNode>
    ) => {
      for (let i = 0; i < token.text.length; i++) {
        const char_info = token.info[i];
        const classes = Object.keys(char_info.renderOptions.classes);

        const style: React.CSSProperties = char_info.renderOptions.style || {};
        if (char_info.highlight) {
          Object.assign(style, this.props.highlightStyle);
        }
        if (char_info.accent) {
          Object.assign(style, this.props.accentStyle);
        }
        if (char_info.cursor) {
          if (cursorBetween) {
            emit(cursorBetweenDiv(token.index + i));
          } else {
            classes.push('cursor');
            Object.assign(style, this.props.cursorStyle);
          }
        }

        const column = token.index + i;
        let href = null;
        let target = null;
        if (char_info.renderOptions.href) {
          href = char_info.renderOptions.href;
          target = '_blank';
        }

        let onClick = undefined;
        if (href == null) {
          if (char_info.renderOptions.onClick !== undefined) {
            onClick = char_info.renderOptions.onClick;
          } else if (this.props.onCharClick) {
            onClick = this.props.onCharClick.bind(this, column);
          }
        }
        const divType = char_info.renderOptions.divType || 'span';
        emit(
          React.createElement(
            divType,
            {
              style: style,
              key: `default-${column}`,
              className: classes.join(' '),
              onClick: onClick,
              href: href,
              target: target
            } as React.DOMAttributes<any>,
            token.text[i] as React.ReactNode
          )
        );
      }

    });

    let lineHook;
    if (this.props.lineHook) {
      lineHook = this.props.lineHook;
    } else {
      lineHook = PartialUnfolder.trivial<Token, React.ReactNode>();
    }
    const LineTokenizer: PartialTokenizer = RegexTokenizerSplitter(
      new RegExp('(\n)'),
      (token: Token, emit: EmitFn<React.ReactNode>) => {
        if (token.text.length !== 1) {
          throw new Error('Expected matched newline of length 1');
        }
        if (token.info.length !== 1) {
          throw new Error('Expected matched newline with info of length 1');
        }
        const char_info = token.info[0];
        const style: React.CSSProperties = char_info.renderOptions.style || {};
        const classes = Object.keys(char_info.renderOptions.classes);
        if (char_info.highlight) {
          Object.assign(style, this.props.highlightStyle);
        }
        if (char_info.accent) {
          Object.assign(style, this.props.accentStyle);
        }
        if (char_info.cursor) {
          if (cursorBetween) {
            emit(cursorBetweenDiv(token.index));
          } else {
            classes.push('cursor');
            Object.assign(style, this.props.cursorStyle);
            emit(React.createElement(
              'span',
              {
                style: style,
                key: `cursor-${token.index}`,
                className: classes.join(' '),
                onClick: undefined,
              } as React.DOMAttributes<any>,
              cursorChar as React.ReactNode
            ));
          }
        }

        emit(React.createElement(
          'div',
          {
            key: `newline-${token.index}`,
            className: classes.join(' '),
            onClick: undefined,
          } as React.DOMAttributes<any>,
          '' as React.ReactNode
        ));
      }
    );

    let wordHook;
    if (this.props.wordHook) {
      wordHook = this.props.wordHook;
    } else {
      wordHook = PartialUnfolder.trivial<Token, React.ReactNode>();
    }
    wordHook = wordHook.then(new PartialUnfolder<Token, React.ReactNode>((
      token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer
    ) => {
      if (text_utils.isLink(token.text)) {
        token.info.forEach((char_info) => {
          char_info.renderOptions.divType = 'a';
          char_info.renderOptions.style = char_info.renderOptions.style || {};
          Object.assign(char_info.renderOptions.style, this.props.linksStyle);
          char_info.renderOptions.onClick = null;
          char_info.renderOptions.href = token.text;
        });
      }
      emit(...wrapped.unfold(token));
    }));

    const WordTokenizer: PartialTokenizer = RegexTokenizerSplitter(
      new RegExp('([^' + word_boundary_chars + ']+)'),
      wordHook.partial_fn
    );

    let tokenizer = lineHook
      .then(LineTokenizer)
      .then(WordTokenizer)
      .finish(DefaultTokenizer);

    // NOTE: this doesn't seem to work for the breadcrumbs, e.g. try visual selecting word at end

    // - start with a plain text string
    // - allow custom "sentence" tokenization first
    // - then tokenize into words
    // - allow more custom "word" tokenization
    const info: Array<CharInfo> = [];
    for (let i = 0; i < lineData.length; i++) {
      const char_info: CharInfo = {
        highlight: i in highlights,
        cursor: i in cursors,
        accent: i in accents,
        renderOptions: {
          classes: {},
        },
      };
      info.push(char_info);
    }
    let token: Token = {
      index: 0,
      length: lineData.length,
      text: lineData.join(''),
      info: info,
    };
    const results = tokenizer.unfold(token);
    return (
      <span>
        {results}
      </span>
    );
  }
}
