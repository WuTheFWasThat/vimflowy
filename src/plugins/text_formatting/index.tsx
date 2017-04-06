import React from 'react'; // tslint:disable-line no-unused-variable

import { Token, RegexTokenizerSplitter, EmitFn, Tokenizer, SliceToken } from '../../assets/js/utils/token_unfolder';
import { registerPlugin } from '../../assets/js/plugins';

// ignore the group, allow whitespace, beginning of line, or open paren
const formatPreRegex = '(?:\\s|^|\\()';
// ignore the group, allow whitespace, end of line, punctuation, or close paren
const formatPostRegex = '(?:\\s|$|\\.|,|!|\\?|\\))';

const boldClass = 'bold';
const italicsClass = 'italic';
const underlineClass = 'underline';

registerPlugin<void>(
  {
    name: 'Text Formatting',
    author: 'Jeff Wu',
    description: `
    Lets you:
    - italicize text by surrounding with *asterisks*
    - bold text by surrounding with **double asterisks**
    - underline text by surrounding with _underscores_
    `,
  },
  function(api) {
    api.registerHook('session', 'renderLineTokenHook', (tokenizer, info) => {
      if (info.has_cursor) {
        return tokenizer;
      }
      if (info.has_highlight) {
        return tokenizer;
      }
      return tokenizer.then(RegexTokenizerSplitter<React.ReactNode>(
        new RegExp(formatPreRegex + '(\\*\\*(\\n|.)+?\\*\\*)' + formatPostRegex),
        (token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer<React.ReactNode>) => {
          token = SliceToken(token, 2, -2);
          token.info.forEach((char_info) => {
            char_info.renderOptions.classes[boldClass] = true;
          })
          emit(...wrapped.unfold(token));
        }
      )).then(RegexTokenizerSplitter<React.ReactNode>(
        new RegExp(formatPreRegex + '(\\*(\\n|.)+?\\*)' + formatPostRegex),
        (token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer<React.ReactNode>) => {
          token = SliceToken(token, 1, -1);
          token.info.forEach((char_info) => {
            char_info.renderOptions.classes[italicsClass] = true;
          })
          emit(...wrapped.unfold(token));
        }
      )).then(RegexTokenizerSplitter<React.ReactNode>(
        new RegExp(formatPreRegex + '(_(\\n|.)+?_)' + formatPostRegex),
        (token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer<React.ReactNode>) => {
          token = SliceToken(token, 1, -1);
          token.info.forEach((char_info) => {
            char_info.renderOptions.classes[underlineClass] = true;
          })
          emit(...wrapped.unfold(token));
        }
      ));
    });
  },
  (api => api.deregisterAll()),
);
