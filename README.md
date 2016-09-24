# ![Vimflowy](/static/images/vimflowy-32.png?raw=true) Vimflowy

[![Join Gitter chat](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy)
[![Build Status](https://travis-ci.org/WuTheFWasThat/vimflowy.svg)](https://travis-ci.org/WuTheFWasThat/vimflowy)

This is a productivity tool which draws great inspiration from workflowy and vim.

Try it out!
- [online] (https://vimflowy.bitballoon.com)
- [local/dev](CONTRIBUTING.md)
- [chrome app](https://chrome.google.com/webstore/detail/vimflowy/dkdhbejgjplkmbiglmjobppakgmiimei)
  *This will no longer be maintained, as [Chrome apps are getting essentially deprecated](https://blog.chromium.org/2016/08/from-chrome-apps-to-web.html).*

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
- Plugins system (see [PLUGINS.md](PLUGINS.md))
  - marks (not like vim's)
  - easy-motion for moving between bullets quickly
  - time-tracking

## NOTES ##

- The app is entirely local. The online version uses localStorage, so it should be used in only one browser.
  If you're going to have a large document, use a browser with large localStorage limits
- Currently, there is no simultaneous editing
- Tested mostly in Chrome and Firefox
- There are [known inconsistencies with vim](vim_inconsistencies.md)
- Contributions are very welcome!  See [CONTRIBUTING.md](CONTRIBUTING.md) if you're interested

### LICENSE ###

MIT: https://wuthefwasthat.mit-license.org/
