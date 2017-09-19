# ![Vimflowy](/static/images/vimflowy-32.png?raw=true) Vimflowy

[![Join Gitter chat](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy)
[![Build Status](https://travis-ci.org/WuTheFWasThat/vimflowy.svg?branch=master)](https://travis-ci.org/WuTheFWasThat/vimflowy?branch=master)

This is a productivity tool which draws some inspiration from workflowy and vim.

[![Bitballoon logo](/docs/media/bitballoon-logo.png) Try it out!](https://vimflowy.bitballoon.com)

[![Docker logo](/docs/media/docker-logo.png) Deploy with docker!](https://hub.docker.com/r/vimflowy/vimflowy/)

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
  - data import from or export as text file (native Vimflowy format or Workflowy-compatible format)
  - loads data lazily (good for huge documents)
  - search (not like vim's)
  - cloning (bullets duplicated in multiple locations in a document)
  - customizable visual themes

## LIMITATIONS

- Global search is slow for large documents (so you'll want to use marks)
- No collaborative editing
- You may need a relatively modern browser.  It should at least support HTML5 LocalStorage and Flexbox.  I test only in recent versions of Chrome and Firefox.

## DATA STORAGE

Vimflowy was designed to work with multiple storage backends.

By default, you own your own data, as it is stored locally on your computer.
However, you can let Google host it for you, or host it yourself.

[See here for more info](docs/storage/README.md).

### SELF-HOSTING

See the [deployment documentation](docs/deployment.md) for details.
You can deploy with docker, or build yourself from source.

## NOTES FOR DEVELOPERS

Contributions are very welcome!
See [dev_setup.md](docs/dev_setup.md) to see how to get started with a development setup.

#### LICENSE

MIT: https://wuthefwasthat.mit-license.org/

## FAQ (AKA questions I imagine people would ask me)

[see here](docs/FAQ.md)
