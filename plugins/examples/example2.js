(function () {
  Plugins.register({
    name: "Hello World js",
    version: 1,
    author: "Jeff Wu",
    description: "Prints 'Hello World' when the plugin is loaded",
    dependencies: [],
  }, function (api) {
    console.log("Hello world plugin written in plain javascript!");
  }, function () {
    console.log("Goodbye, world! - js");
  });
})();
