const Plugins = require('../../assets/js/plugins');

Plugins.register({
  name: 'Hello World example',
  version: 1,
  author: 'Jeff Wu',
  description: 'Prints \'Hello World\' when the plugin is loaded',
}, function (/* api */) {
  console.log('Example plugin: Hello world!');
}, function (/* api */) {
  console.log('Example plugin: Goodbye world!');
});
