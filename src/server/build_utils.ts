import * as express from 'express';
import * as webpack from 'webpack';
import * as WebpackDevServer from 'webpack-dev-server';

import { getProdConfig, getDevConfig, staticDir, publicPath } from './webpack_configs';

export async function buildProd() {
  await new Promise((resolve, reject) => {
    webpack(getProdConfig(), function(err) {
      if (err) { return reject(err); }
      resolve();
    });
  });
}

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
    if (err) { return console.log(err); }
    console.log(`Listening at http://localhost:${port}`);
  });
}
