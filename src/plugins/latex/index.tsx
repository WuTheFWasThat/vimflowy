import React from 'react'; // tslint:disable-line no-unused-variable
///<reference path="typings/katex.d.ts"/>
import katex from 'katex';
///<reference path="typings/react-katex.d.ts"/>
import { InlineMath, BlockMath } from 'react-katex';
import 'katex/dist/katex.min.css';

import { Token, RegexTokenizerSplitter, EmitFn } from '../../assets/js/utils/token_scanner';
import { registerPlugin } from '../../assets/js/plugins';

registerPlugin<void>(
  {
    name: 'LaTeX',
    author: 'Jeff Wu',
    description: `
      Lets you inline LaTeX between $ delimiters,
      or add block LaTeX between $$ delimiters.
    `,
  },
  function(api) {
    api.registerHook('session', 'renderLineTokenHook', (tokenizer) => {
      return tokenizer.chain(RegexTokenizerSplitter<React.ReactNode>(
        new RegExp('(?:\\s|^)(\\$\\$.+\\$\\$)(?:\\s|$)'),
        (token: Token, emitToken: EmitFn<Token>, emit: EmitFn<React.ReactNode>) => {
          for (let i = 0; i < token.info.length; i++) {
            if (token.info[i].cursor) {
              return emitToken(token);
            }
            if (token.info[i].highlight) {
              return emitToken(token);
            }
          }
          try {
            katex.__parse(token.text.slice(2, -2));
            emit(
              <BlockMath key={`latex-${token.index}`}>
                {token.text.slice(2, -2)}
              </BlockMath>
            );
          } catch (e) {
            emitToken(token);
          }
        }
      )).chain(RegexTokenizerSplitter<React.ReactNode>(
        new RegExp('(?:\\s|^)(\\$.+\\$)(?:\\s|$)'),
        (token: Token, emitToken: EmitFn<Token>, emit: EmitFn<React.ReactNode>) => {
          for (let i = 0; i < token.info.length; i++) {
            if (token.info[i].cursor) {
              return emitToken(token);
            }
            if (token.info[i].highlight) {
              return emitToken(token);
            }
          }
          try {
            katex.__parse(token.text.slice(-1, 1));
            emit(
              <InlineMath key={`latex-${token.index}`}>
                {token.text.slice(1, -1)}
              </InlineMath>
            );
          } catch (e) {
            emitToken(token);
          }
        }
      ));
    });
  },
  (api => api.deregisterAll()),
);
