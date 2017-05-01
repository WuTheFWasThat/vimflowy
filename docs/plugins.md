NOTE: *Plugins is currently a work in progress.  The API is unstable.*

However, once a plugin is on the master branch, it'll continue to be maintained.
Please feel free to contact the maintainers of this repository if you're thinking about making a plugin.

# Getting started

First, see [here](./dev_setup.md) for details on development setup.

To make a plugin, make a directory `src/plugins/[YOUR_PLUGIN_NAME]`, with an `index.ts` file.
Then add an import of your directory to [src/plugins/index.ts](../src/plugins/index.ts).

In general, you should be making minimal changes outside your plugin folder.
You may write your plugin in either Javascript or Typescript.
For styles, you can simply import a CSS or SASS stylesheet from your index file.

See the ["hello world" sample plugin](../src/plugins/examples/index.ts) for an extremely minimal example.
More involved examples can be found [here](../src/plugins).

# Plugin API

## Registering a plugin

A plugin registers using

```
Plugins.register(metadata, enable: fn, disable: ?fn)
```
where
- `metadata`:  For the detailed format, read the type definitions in [plugins.ts](../src/assets/js/plugins.ts)
  - name: string
    This will be displayed to the user in options. It should not be changed!
  - version: number
  - author?: string
  - description?: string | React.ReactNode
- `async enable(api)`:
  Called when the plugin is enabled
  Can optionally return a value, in which case other plugins that depend on yours will get access to it.
- `async disable(api)`:
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

A **motion** is a movement of a cursor.

An **action** is a manipulation of the document/underlying data.

A **mapping** is a map from action/motion names to a set of key sequences used to trigger that action or motion.
Actions may optionally accept motions and do something with the motion
(e.g. move the cursor according to the movement, or delete text according to the movement).
To accept a motion, an action's mapping must have a special key '<motion>' which means any sequence for a motion.

For other example usages, see the folder [`src/assets/js/definitions`](../src/assets/js/definitions), and the easy-motion plugin.

```
    api.registerMode(metadata) -> mode
    api.registerMotion(name, description, definition) -> Motion
    api.registerAction(name, description, definition) -> Action
    api.registerDefaultMappings(mode, mappings)
```

In your plugin's disable function, you'll want to deregister everything, in reverse order of registration:
```
    api.deregisterAll
```
You can also manually call each deregister, but this is not recomended
```
    api.deregisterMode(mode)
    api.deregisterMotion(name)
    api.deregisterAction(name)
    api.deregisterDefaultMappings(mode, mappings)
```

See [`keyDefinitions.ts`](../src/assets/js/keyDefinitions.ts) for detailed schema for the metadata of each of these.

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
    async api.panic(message):  Report a fatal problem in the plugin
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

If you use rendering hooks, you must also inform Vimflowy internals when a row should be rerendered.
To do this, simply call `api.updatedDataForRender(row)`.

*More detailed info will be added in the future.*

#### data persistence

The data API is a simple key-value store:
```
    async api.getData(key: string, default_value: T = null) -> Promise<T>:
        Gets value for a key.
        Default value is returned if key doesn't exist
    async api.setData(key: string, value: T) -> Promise<void>
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
