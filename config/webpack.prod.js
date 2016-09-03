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
        loader: ['babel'],
        query: {
          presets: ['es2015', 'react'],
          plugins: []
        },
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
        test: /\.sass$/,
        loaders: ['style', 'css', 'sass']
      },
    ]
  },
  output: {
    path: path.join(__dirname, '..', 'build'),
    filename: 'app.js',
    publicPath: '/static/'
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
