import * as path from 'path';

import * as minimist from 'minimist';
import * as webpack from 'webpack';

import { defaultBuildDir } from './constants';
import { getProdConfig } from './webpack_configs';

export async function buildProd(outdir: string = defaultBuildDir) {
  await new Promise((resolve, reject) => {
    webpack(getProdConfig({ outdir }), function(err) {
      if (err) { return reject(err); }
      resolve();
    });
  });
}

async function main(args: any) {
  if (args.help || args.h) {
    process.stdout.write(`
      Usage: ./node_modules/.bin/ts-node ${process.argv[1]}
          -h, --help: help menu
          --outdir $outdir: Where build output should go
    `, () => {
      process.exit(0);
    });
    return;
  }
  await buildProd(path.resolve(args.outdir || defaultBuildDir));

}

main(minimist(process.argv.slice(2)));
