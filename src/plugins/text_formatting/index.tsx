import React from 'react'; // tslint:disable-line no-unused-variable

import {
  Token, CharInfo, EmitFn, Tokenizer, PartialTokenizer, PartialUnfolder
} from '../../assets/js/utils/token_unfolder';
import { registerPlugin } from '../../assets/js/plugins';

// ignore the group, allow whitespace or beginning of line, then open paren
const formatPreRegex = '(?:\\s|^)(?:\\()*';
// ignore the group, allow end parens, punctuation, then whitespace or end of line
const formatPostRegex = '(?:\\))*(?:\\.|,|!|\\?)*(?:\\s|$)';

const hiddenClass = 'hidden';
const boldClass = 'bold';
const italicsClass = 'italic';
const underlineClass = 'underline';

// captures first group of regex and allows modifying the tokens
function RegexTokenizerModifier<T>(
  regex: RegExp, change_info: (info: Array<CharInfo>) => void
): PartialTokenizer<T> {
  return new PartialUnfolder<Token, T>((
    token: Token, emit: EmitFn<T>, wrapped: Tokenizer<T>
  ) => {
    let index = 0;
    while (true) {
      let match = regex.exec(token.text.slice(index));
      if (!match) { break; }

      // index of match, plus index of group in match
      let start = index + match.index + match[0].indexOf(match[1]);
      let end = start + match[1].length;

      change_info(token.info.slice(start, end));
      index = end;
    }

    emit(...wrapped.unfold(token));
  });
};

function hideOrAddClassToInfo(
  info: Array<CharInfo>, cls: string,
  left_border_to_hide_size: number, right_border_to_hide_size: number
) {
  info.slice(0, left_border_to_hide_size).forEach((char_info) => {
    char_info.renderOptions.classes[hiddenClass] = true;
  });
  info.slice(left_border_to_hide_size, -right_border_to_hide_size).forEach((char_info) => {
    char_info.renderOptions.classes[cls] = true;
  });
  info.slice(-right_border_to_hide_size).forEach((char_info) => {
    char_info.renderOptions.classes[hiddenClass] = true;
  });
}

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
    api.registerHook('session', 'renderLineTokenHook', (tokenizer, hooksInfo) => {
      if (hooksInfo.has_cursor) {
        return tokenizer;
      }
      if (hooksInfo.has_highlight) {
        return tokenizer;
      }
      return tokenizer.then(RegexTokenizerModifier<React.ReactNode>(
        new RegExp(formatPreRegex + '(\\*\\*(\\n|.)+?\\*\\*)' + formatPostRegex),
        (info: Array<CharInfo>) => { hideOrAddClassToInfo(info, boldClass, 2, 2); }
      )).then(RegexTokenizerModifier<React.ReactNode>(
        // middle is either a single character, or both sides have a non-* character
        new RegExp(formatPreRegex + '(\\*((\\n|[^\\*])|[^\\*](\\n|.)+?[^\\*])?\\*)' + formatPostRegex),
        (info: Array<CharInfo>) => { hideOrAddClassToInfo(info, italicsClass, 1, 1); }
      )).then(RegexTokenizerModifier<React.ReactNode>(
        new RegExp(formatPreRegex + '(_(\\n|.)+?_)' + formatPostRegex),
        (info: Array<CharInfo>) => { hideOrAddClassToInfo(info, underlineClass, 1, 1); }
      ));
    });
  },
  (api => api.deregisterAll()),
);
