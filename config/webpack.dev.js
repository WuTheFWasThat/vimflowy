var webpack = require('webpack');
var path = require('path');
var AsyncAwaitPlugin = require('webpack-async-await') ;

var APP_DIR = path.join(__dirname, '..', 'assets');

module.exports = {
  debug: true,
  devtool: 'eval',
  entry: ['webpack-hot-middleware/client', './assets/js/app.js'],
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
        test: /\.sass$/,
        loaders: ['style', 'css', 'sass']
      },
    ]
  },
  output: {
    filename: 'app.js',
    path: path.join(__dirname, '..', 'build'),
    publicPath: '/static/'
  },
  plugins: [
    new AsyncAwaitPlugin({}),
    new webpack.HotModuleReplacementPlugin(),
    new webpack.NoErrorsPlugin()
  ],
  resolve: {
    root: [path.resolve('../app')],
    extensions: ['', '.jsx', '.js', '.tsx', '.ts']
  }
};
