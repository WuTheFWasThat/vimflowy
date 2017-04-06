import * as React from 'react';
import * as _ from 'lodash';

import * as utils from '../utils';
import { Col, Line } from '../types';
import {
  EmitFn, Token, Tokenizer, PartialTokenizer,
  RegexTokenizerSplitter, CharInfo, Unfolder, PartialUnfolder
} from '../utils/token_unfolder';

export type LineProps = {
  lineData: Line;
  cursors?: {[key: number]: boolean};
  highlights?: {[key: number]: boolean};
  lineHook?: PartialUnfolder<Token, React.ReactNode>;
  wordHook?: PartialUnfolder<Token, React.ReactNode>;
  onCharClick?: ((col: Col, e: Event) => void) | null;
  cursorBetween?: boolean;
};

export function getClassesFromInfo(info: CharInfo, cursorBetween: boolean): Array<string> {
  const classes: Array<string> = [];

  if (info.cursor && !cursorBetween) {
    classes.push('cursor', 'theme-cursor');
  }
  if (info.highlight) {
    classes.push('theme-bg-highlight');
  }
  Object.keys(info.renderOptions.classes).forEach((cls) => {
    classes.push(cls);
  });
  return classes;
}


// NOTE: hacky! we don't include .:/ since urls contain it
// should instead make tokenizer for URLs
// also not including @ for marks
const word_boundary_chars = '\t\r\n ,?!()\"\'*+\\;<=>\\[\\]`{}|';

export default class LineComponent extends React.Component<LineProps, {}> {

  constructor(props: LineProps) {
    super(props);
  }

  public render() {
    const cursorBetween: boolean = this.props.cursorBetween || false;
    const lineData = _.cloneDeep(this.props.lineData);
    const cursors = this.props.cursors || {};
    const highlights = this.props.highlights || {};

    // ideally this takes up space but is unselectable (uncopyable)
    const cursorChar = ' ';

    // add cursor if at end
    if (lineData.length in cursors) {
      lineData.push(cursorChar);
    }

    if (lineData.length === 0) {
      return <span></span>;
    }

    function cursorBetweenDiv(i: number) {
      return (
        <div key={`insert-cursor-${i}`}
          className='cursor theme-cursor blink-background'
          style={{
            display: 'inline-block',
            height: '1.2em', width: 2, marginLeft: -1, marginRight: -1,
          }}>
          {' '}
        </div>
      );
    }

    const DefaultTokenizer: Tokenizer<React.ReactNode> = new Unfolder<Token, React.ReactNode>((
      token: Token, emit: EmitFn<React.ReactNode>
    ) => {
      for (let i = 0; i < token.text.length; i++) {
        const info = token.info[i];
        const classes = getClassesFromInfo(info, cursorBetween);
        if (cursorBetween && info.cursor) {
          emit(cursorBetweenDiv(token.index + i));
        }

        const column = token.index + i;
        let href = null;
        if (info.renderOptions.href) {
          href = info.renderOptions.href;
        }

        let onClick = null;
        if (href == null) {
          if (info.renderOptions.onClick !== undefined) {
            onClick = info.renderOptions.onClick;
          } else if (this.props.onCharClick) {
            onClick = this.props.onCharClick.bind(this, column);
          }
        }
        const divType = info.renderOptions.divType || 'span';
        emit(
          React.createElement(
            divType,
            {
              key: `default-${column}`,
              className: classes.join(' '),
              onClick: onClick,
              href: href,
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
    const LineTokenizer: PartialTokenizer<React.ReactNode> =
      RegexTokenizerSplitter<React.ReactNode>(
        new RegExp('(\n)'),
        (token: Token, emit: EmitFn<React.ReactNode>) => {
          if (token.text.length !== 1) {
            throw new Error('Expected matched newline of length 1');
          }
          if (token.info.length !== 1) {
            throw new Error('Expected matched newline with info of length 1');
          }
          const char_info = token.info[0];
          const classes = getClassesFromInfo(char_info, cursorBetween);
          if (char_info.cursor) {
            if (cursorBetween) {
              emit(cursorBetweenDiv(token.index));
            } else {
              emit(React.createElement(
                'span',
                {
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
      token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer<React.ReactNode>
    ) => {
      if (utils.isLink(token.text)) {
        token.info.forEach((char_info) => {
          char_info.renderOptions.divType = 'a';
          char_info.renderOptions.classes['theme-text-link'] = true;
          char_info.renderOptions.onClick = null;
          char_info.renderOptions.href = token.text;
        });
      }
      emit(...wrapped.unfold(token));
    }));

    const WordTokenizer: PartialTokenizer<React.ReactNode> =
      RegexTokenizerSplitter<React.ReactNode>(
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
