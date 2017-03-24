import React from 'react'; // tslint:disable-line no-unused-variable

import { Token, RegexTokenizerSplitter, EmitFn } from '../../assets/js/utils/token_scanner';
import { registerPlugin } from '../../assets/js/plugins';

const htmlTypes: Array<string> = [
  'div',
  'span',
  'img',
  'table'
];

const htmlRegexParts: Array<string> = [];
htmlTypes.forEach((htmltype) => {
  htmlRegexParts.push(
    `<${htmltype}(.|\\n)*>(.|\\n)*</${htmltype}>`
  );
  // self-closing
  htmlRegexParts.push(
    `<${htmltype}(.|\\n)*/>`
  );
});
const htmlRegex = '(' + htmlRegexParts.map((part) => '(' + part + ')').join('|') + ')';

registerPlugin<void>(
  {
    name: 'HTML',
    author: 'Jeff Wu',
    description: `
      Lets you inline the following html tags:
        ${ htmlTypes.map((htmltype) => '<' + htmltype + '>').join(' ') }
    `,
  },
  function(api) {
    api.registerHook('session', 'renderLineTokenHook', (tokenizer) => {
      return tokenizer.chain(RegexTokenizerSplitter<React.ReactNode>(
        new RegExp(htmlRegex),
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
            emit(<span
              key={`html-${token.index}`}
              dangerouslySetInnerHTML={{__html: token.text}}
            />);
          } catch (e) {
            api.session.showMessage(e.message, { text_class: 'error' });
            emitToken(token);
          }
        }
      ));
    });
  },
  (api => api.deregisterAll()),
);
