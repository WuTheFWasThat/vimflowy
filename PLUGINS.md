# Plugin API

NOTE: PLUGINS IS A WORK IN PROGRESS.  THE API IS INCOMPLETE AND PRONE TO CHANGE

To make a plugin, you can place `.js`, `.css`, `.coffee`, or `.sass` files
anywhere within the `plugins` in the vimflowy source directory.
A "hello world" sample plugin is included, in both coffeescript and plain javascript.
You may have to rebuild vimflowy if using a static distribution.

## Registering a plugin

A plugin registers using

````
Plugins.register(metadata, enableCallback[, disableCallback])
```
where
- `metadata`:  For the detailed format, read the tv4 PLUGIN_SCHEMA in plugins.coffee
  - name (required): string
    This will be displayed to the user in options. It should not be changed!
  - version (required): positive integer
  - author: string
  - description: string
  - dependencies (NOT YET SUPPORTED): array of strings
    names of other plugins you depend on.
  - dataVersion (NOT YET SUPPORTED!): positive integer
    Bump this if the data format ever changes, so users can avoid data corruption
- `enableCallback(api)`:
  Called when the plugin is enabled, which is guaranteed to happen after all dependencies are loaded.
  Can optionally return a value, in which case other plugins that depend on yours will get access to it.
- `disableCallback(api)`:
  Called if the plugin is ever disabled by the user.
  If unimplemented, disabling will simply advise the user to refresh the page.
  If implemented, make sure that the plugin can be disabled and re-enabled multiple times (i.e. enable followed by disabled should not leave state).

Plugins are disabled by default. You can enable your plugin from the plugins section of the settings menu within vimflowy.

## Using the API

The API object (passed to the callbacks) includes the following:

####  metadata
```
    api.metadata:  The entire of metadata object of your plugin
    api.name:  Purely for convenience.  Equivalent to api.metadata.name
```
#### vimflowy internals

```
    api.view:  A reference of the internal @view object in vimflowy
    api.data:  A reference of the internal @data object in vimflowy
    api.cursor:  A reference of the internal @cursor object in vimflowy
```

This section will be documented better in the future, when the API is better and more stable

#### helpers
```
    api.panic():  Report a fatal problem in the plugin
      Shows a message to the user, then unloads and disables the plugin.
    api.logger:  Log message from your plugin using methods on this object
      Call one of: api.logger.debug, api.logger.info, api.logger.warn, api.logger.error, api.logger.fatal
      The default output is to the javascript console.
```

#### data persistence

The data API is a simple key-value store
```
    api.getDataVersion():  The last data version of your plugin this document used
    api.setDataVersion(version)
    api.getData(key):  A key-value store for adding data to the document.
    api.setData(key, value)
```

Make sure to version data!  That way vimflowy can detect incompatible formats upgrades which would otherwise make vimflowy crash.
If possible, document your storage schema. Data migrations may be implemented eventually.

NOTE:
- Data is stored as serialized JSON.  Thus, DO NOT use circular references, or vimflowy will crash.
- Small changes to a large object result in a large write to store.

# Feedback
Please let the vimflowy dev team know if you need help, want additional features, or think the API could be made better in some way.
Contact us on github: https://github.com/WuTheFWasThat/vimflowy
