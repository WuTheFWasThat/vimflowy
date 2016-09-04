NOTE: *PLUGINS IS A WORK IN PROGRESS.  THE API IS INCOMPLETE AND UNSTABLE*

Nevertheless, if you think you've written a useful plugin, please make a PR!
When/if it gets merged, we'll try not to break it.

# Plugin API

To make a plugin, import your javascript from [plugins/index.js](plugins/index.js).
You can import CSS as well, from your javascript file.
See the ["hello world" sample plugin](plugins/examples/example2.js) for an extremely minimal example.

You will have to rebuild vimflowy if using a static distribution.
See [here](CONTRIBUTING.md) for details on development setup.

Generally, this documentation may be less useful than just [looking at some example plugins](plugins).

## Registering a plugin

A plugin registers using

````
Plugins.register(metadata, enableCallback[, disableCallback])
```
where
- `metadata`:  For the detailed format, read the tv4 PLUGIN_SCHEMA in [plugins.js](assets/js/plugins.js)
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

First, some terminology:

A **mode** is an editing mode, ala modal editing.
Commands are always executed in the context of a mode.
The function `session.setMode(mode)` changes what mode you're in.

A **command** is a building block for defining an action and/or motion.
It can be used combinatorially in different motions/action definitions.
Each command is assigned default hotkeys, and can be thought of as a layer of indirection above keypresses.

A **motion** is a movement of a cursor.
It is defined by associating a sequence of commands with a function (that mutates a cursor).

An **action** is a manipulation of the document/underlying data.
It is defined by associating a sequence of commands with a function to perform the action, for a given set of modes.
There is a special 'MOTION' command which lets an action use any motion as a subroutine.
See the definitions of yank and delete, in [`assets/js/definitions/basics.js`](assets/js/definitions/basics.js), for an example.

For other example usages, see the folder [`assets/js/definitions`](assets/js/definitions), and the easy-motion plugin.

```
    api.registerMode(metadata) -> mode
    api.registerCommand(metadata) -> command
    api.registerMotion(commands, metadata, fn)
    api.registerAction(modes, commands, metadata, fn)
```

In your plugin's disable function, you'll want to deregister everything, in reverse order of registration:
```
    api.deregisterAll
```
You can also manually call each deregister, but this is not recomended
```
    api.deregisterMode(mode)
    api.deregisterCommand(command)
    api.deregisterMotion(commands)
    api.deregisterAction(modes, commands)
```

See [`keyDefinitions.js`](assets/js/keyDefinitions.js) for detailed schema for the metadata of each of these.

#### vimflowy internals

```
    api.session:   A reference of the internal @session object in vimflowy
                   A session tracks the cursor, history, as well as the actual document
    api.cursor:    A reference of the internal @cursor object in vimflowy
    api.document:  A reference of the internal @document object in vimflowy
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

#### Listeners and hooks

We expose an API for both event listeners and data-mutating hooks
```
    api.registerListener(object, eventname, fn),
    api.deregisterListener(object, eventname, fn),

    api.registerHook(object, hookname, fn),
    api.deregisterHook(object, hookname, fn),
```
where:

`object` is the object to register the listener or hook with (currently either "session" or "document")

For listeners:
- `eventname` is the name of the event being registered
- `fn(arguments...)` is a callback receiving whatever values were emitted by the event

For hooks:
- `hookname` is the name of the hook being registered
- `fn(value, info)` is a callback taking some value and some additional information the hook provides, and which should return a new value.
  In the case of rendering hooks, for example, the value is a ReactDOM element (or array of them),
  and thus the hook function should return a new ReactDOM element (or array of them).

*More detailed info will be added in the future.*

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
