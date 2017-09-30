import * as path from 'path';

import * as minimist from 'minimist';
import * as webpack from 'webpack';

import logger from '../shared/utils/logger';

import { getProdServerConfig } from './webpack_configs';

export async function buildProdServer(outdir: string) {
  await new Promise((resolve, reject) => {
    webpack(getProdServerConfig({ outdir }), function(err) {
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
  if (!args.outdir) {
    logger.error('Please specify --outdir indicating where to output!');
  }
  await buildProdServer(path.resolve(args.outdir));

}

main(minimist(process.argv.slice(2)));
