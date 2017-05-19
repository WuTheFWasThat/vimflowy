NOTE: The plugins API is generally subject to change.
However, once a plugin is on the master branch, it'll continue to be maintained.
Please feel free to contact the maintainers of this repository if you're thinking about making a plugin.

# Getting started

First, see [here](./dev_setup.md) for details on development setup.

To make a plugin, make a directory `src/plugins/[YOUR_PLUGIN_NAME]`, with an `index.ts` file.
Then add an import of your directory to [src/plugins/index.ts](../src/plugins/index.ts).

In general, you should be making minimal changes outside your plugin folder.
You may write your plugin in either Javascript or Typescript, but Typescript should be preferred.
For styles, you can simply import a CSS or SASS stylesheet from your index file.

See the ["hello world" sample plugin](../src/plugins/examples/index.ts) for an extremely minimal example.
More involved examples can be found [here](../src/plugins).

# Plugin API

Currently, all plugins are per-document.  (This is sometimes awkward, since, for example, easy-motion should probably be per-client.  Please let us know if you need per-client plugins.)

## Registering a plugin

A plugin registers using

```
Plugins.register(metadata, enable: fn, disable: ?fn)
```
where
- `metadata`:  For the detailed format, read the type definitions in [plugins.ts](../src/assets/ts/plugins.ts)
  - name: string
    This will be displayed to the user in options. It should not be changed!
  - version: number
    Not used, at the moment
  - author?: string
  - description?: string | React.ReactNode
- `async enable(api)`:
  Called when the plugin is enabled
  Can optionally return a value which is accessible to other plugins.
- `async disable(api, value)`:
  Called if the plugin is ever disabled by the user.
  If unimplemented, disabling will simply advise the user to refresh the page.
  If implemented, make sure that the plugin can be disabled and re-enabled multiple times (i.e. enable followed by disabled should not leave state).

Plugins are generally disabled by default.

In the UI, you can enable your plugin from the plugins section of the Settings menu.
You can make it enabled by default, in [settings.ts](../src/assets/ts/settings.ts).

## Using the API

The API object (passed to the callbacks) includes the following:

####  metadata

```
    api.metadata:  The entire of metadata object of your plugin
    api.name:  Purely for convenience.  Equivalent to api.metadata.name
```

#### keybindings

First, some terminology:

A **mode** is an editing mode, e.g. 'INSERT', 'NORMAL', and 'VISUAL'.
Commands are always executed in the context of a mode.
The function `session.setMode(mode)` changes what mode you're in.

A **motion** is a movement of a cursor.

An **action** is a manipulation of the document/underlying data.

A **mapping** is a map from action/motion names to a set of key sequences used to trigger that action or motion.
Actions may optionally accept motions and do something with the motion
(e.g. move the cursor according to the movement, or delete text according to the movement).
To accept a motion, an action's mapping must have a special key '<motion>' which means any sequence for a motion.

For other example usages, see the folder [`src/assets/ts/definitions`](../src/assets/ts/definitions), and the easy-motion plugin.

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

See [`keyDefinitions.ts`](../src/assets/ts/keyDefinitions.ts) for detailed schema for the metadata of each of these.

#### vimflowy internals

```
    api.document:  A reference of the internal Document object in vimflowy
                   The Document corresponds to a vimflowy text file, and exposes methods
                   for querying and mutating it.
    api.cursor:    A reference of the internal Cursor object in vimflowy
    api.session:   A reference of the internal Session object in vimflowy
                   A session tracks the cursor, viewRoot, document, and mutation history
```

This section's documentation will be expanded upon when the API is better and more stable

#### helpers
```
    async api.panic(message):
      Report a fatal problem in the plugin
      Shows a message to the user, then unloads and disables the plugin.
    api.logger:
      An object with the methods logger.debug, logger.info, logger.warn, logger.error, and logger.fatal
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
- Reads are cached on the key level.  You can assume nobody else will write to your data.
- Small changes to a large object result in a large write to store

# Feedback

Please let the vimflowy dev team know if you:
- need help
- want additional features
- think the API and/or documentation sucks

Contact us on github: https://github.com/WuTheFWasThat/vimflowy
