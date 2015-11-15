(function () {
  Plugins.register({
    name: "Hello World Js",
    author: "Jeff Wu",
    description: "Prints 'Hello World' when the plugin is loaded",
    version: 1,
    requirements: [],
  }, function (api) {
    console.log("Hello world plugin written in plain javascript!");
  });
})();
