import React from 'react'; // tslint:disable-line no-unused-variable
import katex from 'katex';
import 'katex/dist/katex.min.css';

import { Tokenizer, Token, RegexTokenizerSplitter, EmitFn } from '../../assets/js/utils/token_unfolder';
import { registerPlugin } from '../../assets/js/plugins';
import { matchWordRegex } from '../../assets/js/utils';

registerPlugin<void>(
  {
    name: 'LaTeX',
    author: 'Jeff Wu',
    description: `
      Lets you inline LaTeX between $ delimiters,
      or add block LaTeX between $$ delimiters.
      Limited to what KaTeX supports.
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
        matchWordRegex('\\$\\$(\\n|.)+?\\$\\$'),
        (token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer<React.ReactNode>) => {
          try {
            const html = katex.renderToString(token.text.slice(2, -2), { displayMode: true });
            emit(<div key={`latex-${token.index}`} dangerouslySetInnerHTML={{__html: html}}/>);
          } catch (e) {
            api.session.showMessage(e.message, { text_class: 'error' });
            emit(...wrapped.unfold(token));
          }
        }
      )).then(RegexTokenizerSplitter<React.ReactNode>(
        matchWordRegex('\\$(\\n|.)+?\\$'),
        (token: Token, emit: EmitFn<React.ReactNode>, wrapped: Tokenizer<React.ReactNode>) => {
          try {
            const html = katex.renderToString(token.text.slice(1, -1), { displayMode: false });
            emit(<span key={`latex-${token.index}`} dangerouslySetInnerHTML={{__html: html}}/>);
          } catch (e) {
            api.session.showMessage(e.message, { text_class: 'error' });
            emit(...wrapped.unfold(token));
          }
        }
      ));
    });
  },
  (api => api.deregisterAll()),
);
