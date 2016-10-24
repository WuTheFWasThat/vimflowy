# ![Vimflowy](/static/images/vimflowy-32.png?raw=true) Vimflowy

[![Join Gitter chat](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy)
[![Build Status](https://travis-ci.org/WuTheFWasThat/vimflowy.svg?branch=master)](https://travis-ci.org/WuTheFWasThat/vimflowy)

This is a productivity tool which draws great inspiration from workflowy and vim.

[Try it out!](https://vimflowy.bitballoon.com)

(Video coming eventually...)

## FEATURES ##

- Workflowy features
  - tree-like outlining
  - collapsing and zooming into bullets
  - basic text formatting, strike through task completion
- Vim features
  - (configurable) vim keybindings
  - modal editing
  - session history (undo, moving through jump history)
  - repeats, macros
- Extras
  - data import/export
  - loads data lazily (good for big documents)
  - search (not like vim's)
  - cloning (bullets with multiple parents)
  - different visual themes
- Plugins system (see [plugins.md](docs/plugins.md))
  - marks (not like vim's)
  - easy-motion for moving between bullets quickly
  - time-tracking

## LIMITATIONS ##

- Currently, you can only edit from one tab at a time.
  There will likely never be collaboration features.
- There are [known inconsistencies with vim](docs/vim_inconsistencies.md)
- Tested mostly in recent Chrome and Firefox.  You may need a relatively modern browser.
- Currently essentially non-functional on mobile

## DATA STORAGE ##

By default, the app is entirely local, and uses localStorage.
So each browser would have its own document.
Since data is local, offline editing is supported.
If you're going to have a very large document, use a browser with large localStorage limits (Firefox, for example).

There is currently an experimental feature for remote data storage.
This allows access from multiple devices.
However, there is no support for offline editing.

Currently, the only backing data storage that has been implemented is Firebase.
See [here](docs/storage/Firebase.md) for details on how to set this up.
Please contact me if you are interested in other storage backings.

## NOTES FOR DEVELOPERS ##

Contributions are very welcome!
See [dev_setup.md](docs/dev_setup.md) to see how to get started with a development setup.

The [chrome app](https://chrome.google.com/webstore/detail/vimflowy/dkdhbejgjplkmbiglmjobppakgmiimei) exists but will no longer be maintained.
[Chrome apps are getting essentially deprecated](https://blog.chromium.org/2016/08/from-chrome-apps-to-web.html).

### LICENSE ###

MIT: https://wuthefwasthat.mit-license.org/
