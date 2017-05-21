import * as path from 'path';
import { spawn } from 'child_process';

import * as minimist from 'minimist';
import * as webpack from 'webpack';
import * as WebpackDevServer from 'webpack-dev-server';

import { setupApp } from './setup';

const args = minimist(process.argv.slice(2));

const config = require('../../webpack.dev');
const staticDir = path.join(__dirname, '../../', 'static');

const port = args.port || 3000;

const server = new WebpackDevServer(webpack(config), {
  publicPath: config.output.publicPath,
  hot: true,
  stats: false,
  historyApiFallback: true
});

setupApp((server as any).app, staticDir);

/* eslint-disable no-console */
server.listen(port, 'localhost', (err: Error) => {
  if (err) {
    return console.log(err);
  }
  console.log(`Listening at http://localhost:${port}`);
});

if (args.test) {
  spawn('npm', ['run', 'watchtest'], {stdio: 'inherit'});
}
