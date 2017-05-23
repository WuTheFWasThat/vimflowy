import * as minimist from 'minimist';
import * as webpack from 'webpack';

import { prodConfig } from './webpack_configs';

async function main(_args: any) {
  await new Promise((resolve, reject) => {
    webpack(prodConfig, function(err) {
      if (err) { return reject(err); }
      resolve();
    });
  });
}

main(minimist(process.argv.slice(2)));
