import * as Plugins from '../../assets/js/plugins';

Plugins.register({
  name: 'Hello World example',
  version: 1,
  author: 'Jeff Wu',
  description: 'Prints \'Hello World\' when the plugin is loaded',
}, function (/* api */) {
  console.log('Example plugin: Hello world!'); // eslint-disable-line no-console
}, function (/* api */) {
  console.log('Example plugin: Goodbye world!'); // eslint-disable-line no-console
});
