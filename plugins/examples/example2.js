var Plugins = require('../../assets/js/plugins');

Plugins.register({
  name: 'Hello World js example',
  version: 1,
  author: 'Jeff Wu',
  description: 'Prints \'Hello World\' when the plugin is loaded',
}, function (/* api */) {
  console.log('Javascript example plugin: Hello world!');
}, function (/* api */) {
  console.log('Javascript example plugin: Goodbye world!');
});
