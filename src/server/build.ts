import * as minimist from 'minimist';
import * as webpack from 'webpack';

import { getProdConfig } from './webpack_configs';

export async function buildProd() {
  await new Promise((resolve, reject) => {
    webpack(getProdConfig(), function(err) {
      if (err) { return reject(err); }
      resolve();
    });
  });
}

async function main(args: any) {
  if (args.help || args.h) {
    // TODO: configurable staticDir?
    process.stdout.write(`
      Usage: ./node_modules/.bin/ts-node ${process.argv[1]}
          -h, --help: help menu
    `, () => {
      process.exit(0);
    });
    return;
  }
  await buildProd();

}

main(minimist(process.argv.slice(2)));
