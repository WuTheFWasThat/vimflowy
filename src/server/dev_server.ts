/* tslint:disable no-console */

import { spawn } from 'child_process';

import * as express from 'express';
import * as minimist from 'minimist';
import * as webpack from 'webpack';
import * as WebpackDevServer from 'webpack-dev-server';

import { devConfig, staticDir, publicPath } from './webpack_configs';

const args = minimist(process.argv.slice(2));

const port = args.port || 3000;

const server = new WebpackDevServer(webpack(devConfig), {
  publicPath: publicPath,
  hot: true,
  stats: false,
  historyApiFallback: true
});

const app: express.Application = (server as any).app;
app.use(express.static(staticDir));

server.listen(port, 'localhost', (err: Error) => {
  if (err) {
    return console.log(err);
  }
  console.log(`Listening at http://localhost:${port}`);
});

if (args.test) {
  spawn('npm', ['run', 'watchtest'], {stdio: 'inherit'});
}
