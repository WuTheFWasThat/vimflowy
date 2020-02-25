import * as fs from 'fs';

import * as webpack from 'webpack';
import { CheckerPlugin } from 'awesome-typescript-loader';

import { publicPath, defaultBuildDir, defaultSrcDir } from './constants';
import { ServerConfig } from '../shared/server_config';


export type BuildConfig = {
  outdir?: string,
  srcdir?: string,
  server_config?: ServerConfig,
};

export function getDevConfig(config: BuildConfig = {}): webpack.Configuration {
  const srcdir = config.srcdir || defaultSrcDir;
  const outdir = config.outdir || defaultBuildDir;
  return {
    devtool: 'eval-source-map',
    entry: [
      'webpack-dev-server/client?http://localhost:3000',
      'webpack/hot/only-dev-server',
      `${srcdir}/assets/ts/app.tsx`
    ],
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          enforce: 'pre',
          use: [
            {
              loader: 'tslint-loader',
              options: { emitErrors: false, failOnHint: false, }
            },
          ],
        },
        {
          test: /\.tsx?$/,
          use: [
            'react-hot-loader', 'awesome-typescript-loader',
          ],
          include: srcdir
        },
        {
          test: /\.(sass|css)$/,
          use: ['style-loader', 'css-loader', 'sass-loader']
        },
        {
          test: /\.(svg|woff|woff2|ttf|eot)(\?.*$|$)/,
          use: ['file-loader']
        },
      ]
    },
    output: {
      filename: 'app.js',
      path: outdir,
      publicPath: publicPath
    },
    plugins: [
      new webpack.HotModuleReplacementPlugin(),
      new webpack.DefinePlugin({
        'process.env': {
          'NODE_ENV': JSON.stringify('development')
        },
        'INJECTED_SERVER_CONFIG': JSON.stringify(config.server_config || {}),
      }),
      new CheckerPlugin(),
      new webpack.LoaderOptionsPlugin({
        options: {
          css: {
            sourceMap: true,
            root: '/build',
          }
        }
      }),
      // new webpack.NoErrorsPlugin(),
    ],
    resolve: {
      extensions: ['.jsx', '.js', '.tsx', '.ts']
    },
    stats: 'verbose'
  };
}

export function getProdConfig(config: BuildConfig = {}): webpack.Configuration {
  const srcdir = config.srcdir || defaultSrcDir;
  const outdir = config.outdir || defaultBuildDir;
  return {
    devtool: 'source-map',
    entry: `${srcdir}/assets/ts/app.tsx`,
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          enforce: 'pre',
          use: [
            {
              loader: 'tslint-loader',
              options: { emitErrors: true, failOnHint: true, }
            },
          ],
        },
        {
          test: /\.tsx?$/,
          use: [
            'awesome-typescript-loader',
          ],
          include: srcdir
        },
        {
          test: /\.(sass|css)$/,
          use: ['style-loader', 'css-loader', 'sass-loader']
        },
        {
          test: /\.(svg|woff|woff2|ttf|eot)(\?.*$|$)/,
          use: ['file-loader']
        },
      ]
    },
    output: {
      filename: 'app.js',
      path: outdir,
      publicPath: publicPath
    },
    optimization: {
      minimize: true
    },
    plugins: [
      new webpack.DefinePlugin({
        'process.env': {
          'NODE_ENV': JSON.stringify('production')
        },
        'INJECTED_SERVER_CONFIG': JSON.stringify(config.server_config || {}),
      }),
      new CheckerPlugin(),
      new webpack.LoaderOptionsPlugin({
        options: {
          css: {
            sourceMap: true,
            root: '/build',
          }
        }
      }),
    ],
    resolve: {
      extensions: ['.jsx', '.js', '.tsx', '.ts']
    },
  };
}

// For more information, on using webpack with node, see:
// http://jlongster.com/Backend-Apps-with-Webpack--Part-I
export function getProdServerConfig(config: BuildConfig = {}): webpack.Configuration {
  const srcdir = config.srcdir || defaultSrcDir;
  const outdir = config.outdir || defaultBuildDir;

  const nodeModules: any = {};
  fs.readdirSync('node_modules').forEach((mod) => {
    nodeModules[mod] = 'commonjs ' + mod;
  });

  return {
    devtool: 'source-map',
    entry: `${srcdir}/server/prod.ts`,
    externals: nodeModules,
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          enforce: 'pre',
          use: [
            {
              loader: 'tslint-loader',
              options: { emitErrors: true, failOnHint: true, }
            },
          ],
        },
        {
          test: /\.ts$/,
          use: [
            'awesome-typescript-loader'
          ],
          include: srcdir
        },
      ]
    },
    target: 'node',
    output: {
      filename: 'server.js',
      path: outdir,
    },
    optimization: {
      minimize: true
    },
    plugins: [
      new CheckerPlugin(),
    ],
    resolve: {
      extensions: ['.js', '.ts']
    },
  };
}
