# ![Vimflowy](/assets/images/vimflowy-32.png?raw=true) Vimflowy

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
  - macros
- Extras
  - data import/export
  - search (not like vim's)
  - cloning (bullets with multiple parents)
  - different visual themes
  - loads data lazily (good for big documents)
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

## CONTRIBUTE ##

Please do!  See [CONTRIBUTING.md](CONTRIBUTING.md)

Don't hesitate to contact me for help.

I've marked a number of github issues with the label `small_task`, which could be good places to start.

### LICENSE ###

MIT: http://wuthefwasthat.mit-license.org/
