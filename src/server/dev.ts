import { spawn } from 'child_process';
import * as http from 'http';

import * as express from 'express';
import * as minimist from 'minimist';
import * as webpack from 'webpack';
import * as WebpackDevServer from 'webpack-dev-server';

import logger from '../assets/ts/utils/logger';

import { getDevConfig, staticDir, publicPath } from './webpack_configs';
import makeSocketServer from './socket_server';

export function makeDevServer(port: number, extraConf: any = {}) {
  const server = new WebpackDevServer(webpack(getDevConfig()), {
    publicPath: publicPath,
    hot: true,
    stats: false,
    historyApiFallback: true,
    ...extraConf
  });

  const app: express.Application = (server as any).app;
  app.use(express.static(staticDir));

  server.listen(port, 'localhost', (err: Error) => {
    if (err) { return logger.error(err); }
    logger.info(`Listening at http://localhost:${port}`);
  });
}

async function main(args: any) {
  if (args.help || args.h) {
    process.stdout.write(`
      Usage: ./node_modules/.bin/ts-node ${process.argv[1]}
          -h, --help: help menu

          --port $portnumber: Port to run on

          --test: Specifies whether to run unit tests upon code change.

          --db $dbtype: If a db is set, we will additionally run a socket server.
            Available options:
            - 'sqlite' to use sqlite backend
            Any other value currently defaults to an in-memory backend.
          --password: password to protect database with (defaults to empty)

          --dbfolder: For sqlite backend only.  Folder for sqlite to store data
            (defaults to in-memory if unspecified)

    `, () => {
      process.exit(0);
    });
    return;
  }

  let port: number = args.port || 3000;

  logger.info('Starting development server');
  const webpack_options: any = {};
  if (args.db) {
    const wsPort = port + 1;
    webpack_options.proxy = {
      '/socket': {
         target: `ws://localhost:${wsPort}`,
         ws: true
      },
    };
    const server = http.createServer(express());
    const options = {
      db: args.db,
      dbfolder: args.dbfolder,
      password: args.password,
    };
    makeSocketServer(server, options);
    server.listen(wsPort, 'localhost', (err: Error) => {
      if (err) { return logger.error(err); }
      logger.info('Internal server listening on http://localhost:%d', server.address().port);
    });
  }
  makeDevServer(port, webpack_options);
  if (args.test) {
    spawn('npm', ['run', 'watchtest'], {stdio: 'inherit'});
  }
}

main(minimist(process.argv.slice(2)));
