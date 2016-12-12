import { registerPlugin } from '../../assets/js/plugins';

registerPlugin({
  name: 'Hello World example',
  version: 1,
  author: 'Jeff Wu',
  description: 'Prints \'Hello World\' when the plugin is loaded',
}, function (api) {
  api.session.showMessage('Example plugin: Hello world!');
}, function (api) {
  api.session.showMessage('Example plugin: Goodbye world!');
});
