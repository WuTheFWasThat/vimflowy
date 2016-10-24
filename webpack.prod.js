var path = require('path');
var webpack = require('webpack');
var AsyncAwaitPlugin = require('webpack-async-await') ;

var SRC_DIR = path.join(__dirname, 'src');

module.exports = {
  devtool: 'source-map',
  entry: './src/assets/js/app.tsx',
  module: {
    loaders: [
      {
        test: /\.jsx?$/,
        loaders: ['babel', 'eslint-loader'],
        include: SRC_DIR,
      },
      {
        test: /\.tsx?$/,
        loaders: [
          'babel', 'awesome-typescript-loader', 'tslint',
        ],
        include: SRC_DIR
      },
      {
        test: /\.(sass|css)$/,
        loaders: ['style', 'css', 'sass']
      },
      {
        test: /\.(svg|woff|woff2|ttf|eot)(\?.*$|$)/,
        loader: 'file'
      },
    ]
  },
  output: {
    filename: 'app.js',
    path: path.join(__dirname, 'static', 'build'),
    publicPath: '/build/'
  },
  plugins: [
    new AsyncAwaitPlugin({}),
    new webpack.optimize.OccurrenceOrderPlugin(),
    new webpack.DefinePlugin({
      'process.env': {
        'NODE_ENV': JSON.stringify('production')
      }
    }),
    new webpack.optimize.UglifyJsPlugin({
      compressor: {
        warnings: false
      }
    })
  ],
  resolve: {
    extensions: ['', '.jsx', '.js', '.tsx', '.ts']
  },
  tslint: {
    emitErrors: true,
    failOnHint: true
  },
  eslint: {
    configFile: '.eslintrc'
  }
};
