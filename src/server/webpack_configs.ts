import * as webpack from 'webpack';
import { CheckerPlugin } from 'awesome-typescript-loader';

import { publicPath, defaultBuildDir, defaultSrcDir } from './constants';

type BuildConfig = {
  outdir?: string,
  srcdir?: string,
};

export function getDevConfig(config: BuildConfig = {}): webpack.Configuration {
  const srcdir = config.srcdir || defaultSrcDir;
  const outdir = config.outdir || defaultBuildDir;
  return {
    devtool: 'eval',
    entry: [
      'webpack-dev-server/client?http://localhost:3000',
      'webpack/hot/only-dev-server',
      `${srcdir}/assets/ts/app.tsx`
    ],
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          use: [
            'react-hot-loader', 'awesome-typescript-loader', 'tslint-loader',
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
      new CheckerPlugin(),
      new webpack.HotModuleReplacementPlugin(),
      new webpack.DefinePlugin({
        'process.env': {
          'NODE_ENV': JSON.stringify('development')
        },
      }),
      new webpack.LoaderOptionsPlugin({
        options: {
          tslint: {
            emitErrors: true,
            failOnHint: true
          },
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
  };
};

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
          use: [
            'awesome-typescript-loader', 'tslint-loader',
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
      new CheckerPlugin(),
      new webpack.DefinePlugin({
        'process.env': {
          'NODE_ENV': JSON.stringify('production')
        },
      }),
      new webpack.optimize.UglifyJsPlugin({
        compress: {
          warnings: false
        }
      }),
      new webpack.LoaderOptionsPlugin({
        options: {
          tslint: {
            emitErrors: true,
            failOnHint: true
          },
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
};
