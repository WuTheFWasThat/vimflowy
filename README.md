# ![Vimflowy](/assets/images/vimflowy-32.png?raw=true) Vimflowy

[![Join the chat at https://gitter.im/WuTheFWasThat/vimflowy](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This is a productivity tool which draws great inspiration from workflowy and vim.

Try it out!
- [online] (https://vimflowy.bitballoon.com)
- [chrome app](https://chrome.google.com/webstore/detail/vimflowy/dkdhbejgjplkmbiglmjobppakgmiimei): This version will be sparsely updated
- [local/dev](CONTRIBUTING.md)

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

MIT: http://wuthefwasthat.mit-license.org/
