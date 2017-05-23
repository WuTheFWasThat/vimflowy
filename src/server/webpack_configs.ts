import * as path from 'path';

import * as webpack from 'webpack';

const SRC_DIR = path.join(__dirname, '../../src');

export const staticDir = path.join(__dirname, '../../', 'static');
export const publicPath = '/build/';
export const buildDir = path.join(staticDir, 'build');

export const devConfig: webpack.Configuration = {
  devtool: 'eval',
  entry: [
    'webpack-dev-server/client?http://localhost:3000',
    'webpack/hot/only-dev-server',
    `${SRC_DIR}/assets/ts/app.tsx`
  ],
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: [
          'react-hot-loader', 'awesome-typescript-loader', 'tslint-loader',
        ],
        include: SRC_DIR
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
    path: buildDir,
    publicPath: '/build/'
  },
  plugins: [
    new webpack.HotModuleReplacementPlugin(),
    new webpack.DefinePlugin({
      'process.env': {
        'NODE_ENV': JSON.stringify('development')
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
    // new webpack.NoErrorsPlugin(),
  ],
  resolve: {
    extensions: ['.jsx', '.js', '.tsx', '.ts']
  },
};

export const prodConfig: webpack.Configuration = {
  devtool: 'source-map',
  entry: `${SRC_DIR}/assets/ts/app.tsx`,
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: [
          'awesome-typescript-loader', 'tslint-loader',
        ],
        include: SRC_DIR
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
    path: buildDir,
    publicPath: '/build/'
  },
  plugins: [
    new webpack.DefinePlugin({
      'process.env': {
        'NODE_ENV': JSON.stringify('production')
      }
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
