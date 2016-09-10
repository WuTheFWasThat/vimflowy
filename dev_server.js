const path = require('path');
const express = require('express');
const webpack = require('webpack');
const config = require('./config/webpack.dev');

const app = express();
const compiler = webpack(config);
const port = process.env.PORT || 3000;

app.use(require('webpack-dev-middleware')(compiler, {
  noInfo: true,
  publicPath: config.output.publicPath
}));

app.use(require('webpack-hot-middleware')(compiler));

app.use(express.static(path.join(__dirname, 'static')));

app.get('/:docname', (req, res) => {
  res.sendFile(path.join(__dirname, 'static/index.html'));
});

/* eslint-disable no-console */
app.listen(port, 'localhost', err => {
  if (err) {
    return console.log(err);
  }
  console.log(`Listening at http://localhost:${port}`);
});

const spawn = require('child_process').spawn;
spawn(
  'node_modules/.bin/mocha',
  ['--compilers', 'js:babel-core/register', '--watch', 'test/tests'],
  {stdio: 'inherit'}
);
