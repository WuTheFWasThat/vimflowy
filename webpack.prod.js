var path = require('path');
var webpack = require('webpack');

var SRC_DIR = path.join(__dirname, 'src');

module.exports = {
  devtool: 'source-map',
  entry: './src/assets/ts/app.tsx',
  module: {
    loaders: [
      {
        test: /\.tsx?$/,
        loaders: [
          'awesome-typescript-loader', 'tslint',
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
  }
};
