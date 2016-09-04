var path = require('path');
var webpack = require('webpack');
var AsyncAwaitPlugin = require('webpack-async-await') ;

var APP_DIR = path.join(__dirname, '..', 'assets');

module.exports = {
  devtool: 'source-map',
  entry: './assets/js/app.js',
  module: {
    preLoaders: [{
      test: /\.tsx?$/,
      loader: 'tslint',
      include: APP_DIR
    }],
    loaders: [
      {
        test: /\.jsx?$/,
        loaders: ['babel'],
        exclude: /node_modules/
        // include: APP_DIR,
        // also should include plugins
      },
      {
        test: /\.tsx?$/,
        loaders: [
          'babel', 'ts'
        ],
        include: APP_DIR
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
    path: path.join(__dirname, '..', 'static', 'build'),
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
    root: [path.resolve('../app')],
    extensions: ['', '.jsx', '.js', '.tsx', '.ts']
  },
  tslint: {
    emitErrors: true,
    failOnHint: true
  }
};
