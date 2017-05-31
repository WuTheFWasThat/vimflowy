import { spawn } from 'child_process';
import * as http from 'http';
import * as fs from 'fs';

import * as express from 'express';
import * as minimist from 'minimist';

import logger from '../assets/ts/utils/logger';

import makeSocketServer from './socket_server';
import { makeDevServer, buildProd } from './build_utils';
import { staticDir, buildDir } from './webpack_configs';

async function main(args: any) {
  if (args.help || args.h) {
    process.stdout.write(`
      Usage: ./node_modules/.bin/ts-node ${process.argv[1]}
          -h, --help: help menu

          --port $portnumber: Port to run on
          --prod: Production mode. Serve static files instead of webpack dev server.
            Defaults to off, dev mode.

          --build: Whether to build assets, before starting server

          --test: For dev mode only.  Specifies whether to run unit tests upon code change.

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

  if (args.prod) {
    if (args.build) {
      logger.info('Building production assets');
      await buildProd();
    } else if (!fs.existsSync(buildDir)) {
      logger.info(`No assets found at ${buildDir}.  Try adding the --build flag.`);
      return;
    }
    logger.info('Starting production server');
    const app = express();
    app.use(express.static(staticDir));
    const server = http.createServer(app);
    if (args.db) {
      const options = {
        db: args.db,
        dbfolder: args.dbfolder,
        password: args.password,
        path: '/socket',
      };
      makeSocketServer(server, options);
    }
    server.listen(port, 'localhost', (err: Error) => {
      if (err) { return logger.error(err); }
      logger.info('Listening on %d', server.address().port);
    });
  } else {
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
        logger.info('Internal server listening on %d', server.address().port);
      });
    }
    makeDevServer(port, webpack_options);
    if (args.test) {
      spawn('npm', ['run', 'watchtest'], {stdio: 'inherit'});
    }
  }
}

main(minimist(process.argv.slice(2)));
