# ![Vimflowy](/static/images/vimflowy-32.png?raw=true) Vimflowy

[![Join Gitter chat](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy)
[![Build Status](https://travis-ci.org/WuTheFWasThat/vimflowy.svg?branch=master)](https://travis-ci.org/WuTheFWasThat/vimflowy)

This is a productivity tool which draws some inspiration from workflowy and vim.

[Try it out!](https://vimflowy.bitballoon.com)

(Video coming eventually...)

## FEATURES

- Workflowy features
  - tree-like outlining
  - collapsing and zooming into bullets
  - basic text formatting, strike through task completion
- Vim features
  - (configurable) vim keybindings
  - modal editing
  - undo history, location history, macros, etc.
- Plugins system (see [plugins.md](docs/plugins.md))
  - marks (not like vim's)
  - easy-motion for moving between bullets quickly
  - time-tracking
  - LaTeX and HTML rendering
- Other
  - data import/export
  - loads data lazily (good for huge documents)
  - search (not like vim's)
  - cloning (bullets duplicated in multiple locations in a document)
  - different visual themes

## LIMITATIONS

- Global search is slow for large documents (so you'll want to use marks)
- No collaborative editing
- You may need a relatively modern browser.  It should at least support HTML5 LocalStorage and Flexbox.  I test only in recent versions of Chrome and Firefox.

## DATA STORAGE

Vimflowy was designed to work with multiple storage backends.

### Local

By default, the app is entirely local meaning:
- Your data is never sent over the internet, so you can only use it in one browser on one device
- Vimflowy works offline

It uses HTML5's localStorage, so:
- If you're going to have a very large document, use a browser with large localStorage limits, e.g. Firefox
- Be warned that if you don't set up remote storage, *clearing localStorage will result in you losing all your data!*

### Remote

If you enable a remote storage backend, then:
- You can access your document from multiple devices
- You cannot edit offline

Currently, the only storage backend implemented is Firebase.
See [here](docs/storage/Firebase.md) for details on how to set this up.

Please contact the dev team if you are interested in other storage backends.

## NOTES FOR DEVELOPERS

Contributions are very welcome!
See [dev_setup.md](docs/dev_setup.md) to see how to get started with a development setup.

#### LICENSE

MIT: https://wuthefwasthat.mit-license.org/

## FAQ (AKA questions I imagine people would ask me)

[see here](docs/FAQ.md)
