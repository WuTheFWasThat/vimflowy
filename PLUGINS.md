NOTE: *PLUGINS IS A WORK IN PROGRESS.  THE API IS INCOMPLETE AND UNSTABLE*

Nevertheless, if you think you've written a useful plugin, please make a PR!
When/if it gets merged, we'll try not to break it.

# Plugin API

To make a plugin, you can place `.js`, `.css`, `.coffee`, or `.sass` files
anywhere within the `plugins` folder in the vimflowy source directory.
A "hello world" sample plugin is included, in both
[coffeescript](plugins/examples/example.coffee) and [plain javascript](plugins/examples/example2.js).

You will have to rebuild vimflowy if using a static distribution.
See [here](CONTRIBUTING.md) for details on development setup.

Generally, this documentation may be less useful than just [looking at some example plugins](plugins).

## Registering a plugin

A plugin registers using

````
Plugins.register(metadata, enableCallback[, disableCallback])
```
where
- `metadata`:  For the detailed format, read the tv4 PLUGIN_SCHEMA in [plugins.coffee](assets/js/plugins.coffee)
  - name (required): string
    This will be displayed to the user in options. It should not be changed!
  - version (required): positive integer
  - author: string
  - description: string
    names of other plugins you depend on.
- `enableCallback(api)`:
  Called when the plugin is enabled
  Can optionally return a value, in which case other plugins that depend on yours will get access to it.
- `disableCallback(api)`:
  Called if the plugin is ever disabled by the user.
  If unimplemented, disabling will simply advise the user to refresh the page.
  If implemented, make sure that the plugin can be disabled and re-enabled multiple times (i.e. enable followed by disabled should not leave state).

Plugins are generally disabled by default.

You can enable your plugin from the plugins section of the settings menu within vimflowy.

## Using the API

The API object (passed to the callbacks) includes the following:

####  metadata
```
    api.metadata:  The entire of metadata object of your plugin
    api.name:  Purely for convenience.  Equivalent to api.metadata.name
```
#### keybindings
We introduce three notions, a **command**, **motion**, and **action**.

A **command** is a building block for defining an action and/or motion.
It can be used combinatorially in different motions/action definitions.
Each command is assigned default hotkeys, and can be thought of as a layer of indirection above keypresses.

A **motion** is a movement of a cursor.
It is defined by associating a sequence of commands with a function (that mutates a cursor).

An **action** is a manipulation of the view and/or underlying data.
It is defined by associating a sequence of commands with a function to perform the action, for a given set of modes.
There is a special 'MOTION' command which lets an action use any motion as a subroutine.
See the definitions of yank and delete, in [`assets/js/definitions/basics.coffee`](assets/js/definitions/basics.coffee), for an example.

For other example usages, see the folder [`assets/js/definitions`](assets/js/definitions), and the easy-motion plugin.

```
    api.registerCommand(metadata)
    api.registerAction(modes, commands, metadata, fn)
    api.registerMotion(commands, metadata, fn)
```
See [`keyDefinitions.coffee`](assets/js/keyDefinitions.coffee) for detailed schema for each of these.

We plan on adding ways to unregister commands/actions/motions.

#### vimflowy internals

```
    api.view:  A reference of the internal @view object in vimflowy
    api.data:  A reference of the internal @data object in vimflowy
    api.cursor:  A reference of the internal @cursor object in vimflowy
```

This section will be documented better in the future, when the API is better and more stable

#### helpers
```
    api.panic(message):  Report a fatal problem in the plugin
      Shows a message to the user, then unloads and disables the plugin.
    api.logger:  Log message from your plugin using methods on this object
      Call one of: api.logger.debug, api.logger.info, api.logger.warn, api.logger.error, api.logger.fatal
      The default output is to the javascript console.
```

#### rendering

We expose an API for rendering via a family of hooks
```
    api.view.addHook(hookname, fn),
```
where `fn(v, info)` is a callback taking a virtualDom element (or array of them) and any additional information the hook provides.
This hook function should return a new virtualDom element (or array of them).

Typically, rendering hooks will have `hookname` beginning with `render`.

More detailed info on these hooks will be added later.

#### data persistence

The data API is a simple key-value store:
```
    api.getData(key, default_value=null):
        Gets value for a key.
        Default value is returned if key doesn't exist
    api.setData(key, value)
        Sets value for a key.
```

The keys should always be strings.  The values can be anything JSON-serializable.

Keep in mind:
- Reads are cached.  It's assumed nobody else is writing data.
- Small changes to a large object result in a large write to store
- Document and version your storage schema when appropriate. Data migrations may be implemented eventually.

# Feedback

Please let the vimflowy dev team know if you need help, want additional features, think the API and/or documentation could be made better in some way, etc.
Contact us on github: https://github.com/WuTheFWasThat/vimflowy
