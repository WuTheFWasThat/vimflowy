import * as path from 'path';

import * as minimist from 'minimist';
import * as webpack from 'webpack';

import { defaultBuildDir } from './constants';
import { getProdConfig } from './webpack_configs';
import { ServerConfig } from '../shared/server_config';

export async function buildProd(server_config: ServerConfig = {}, outdir: string = defaultBuildDir) {
  await new Promise((resolve, reject) => {
    webpack(getProdConfig({ outdir, server_config }), function(err) {
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
          --socketserver: Whether this is a socketserver
    `, () => {
      process.exit(0);
    });
    return;
  }
  const server_config: ServerConfig = {};
  if (args.socketserver) {
    server_config.socketserver = true;
  }
  await buildProd(
    server_config,
    path.resolve(args.outdir || defaultBuildDir)
  );

}

main(minimist(process.argv.slice(2)));
