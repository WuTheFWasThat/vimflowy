# ![Vimflowy](/assets/images/vimflowy-32.png?raw=true) Vimflowy

This is a productivity tool which draws great inspiration from workflowy and vim.

[Try it out online] (https://vimflowy.bitballoon.com), or [download it as a local app](https://chrome.google.com/webstore/detail/vimflowy/dkdhbejgjplkmbiglmjobppakgmiimei)!

(Video coming eventually...)

## NOTES ##

- The app is entirely local. The online version uses localStorage, so it should be used in only one browser.
  If you're going to have a large document, use a browser with large localStorage limits
- Currently, weird things happen when you use multiple tabs simultaneously
- Tested mostly in Chrome and Firefox
- There are [known inconsistencies with vim](vim_inconsistencies.md)

## FEATURES ##

- Workflowy features
  - bullets, sub-bullets
  - collapsing
  - zooming
  - text formatting
    - bold, italic, and underline
    - strike through text (task completion)
- Vim features
  - most of the standard movement/operators
  - modal editing
    - insert and normal mode
    - visual mode (only within a line)
    - visual line (acts on groups of siblings)
  - keybindings for everything
    - configurable (via downloading/uploading a json file)
  - undo!  Full history kept within a session
  - ctrl+o and ctrl+i to move through jump history
  - macros
- Extras
  - search
  - cloning (bullets with multiple parents)
  - data import/export
  - different themes
  - multiple documents in online version (by visiting /documentname)
  - lazy loads data, for big documents
  - plugins system, for adding new features (see [PLUGINS.md](PLUGINS.md))
    - marks (not quite like vim's)
    - easy_motion for moving between bullets quickly
    - time-tracking

## CONTRIBUTE ##

Please do!  See [CONTRIBUTING.md](CONTRIBUTING.md)

### LICENSE ###

MIT: http://wuthefwasthat.mit-license.org/
