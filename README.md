# ![Vimflowy](/public/images/vimflowy-32.png?raw=true) Vimflowy

This is a productivity tool which draws great inspiration from workflowy and vim.

[Try it out online] (https://vimflowy.bitballoon.com), or [download it as a local app](https://chrome.google.com/webstore/detail/vimflowy/dkdhbejgjplkmbiglmjobppakgmiimei)!

(Video coming eventually...)

## NOTES ##

- Vimflowy is currently aimed at vim users, who should feel at home.
The plan is to eventually have very customizable bindings, and defaults for normal people (as well as emacs users).
But for now, if you want to use vimflowy, you should first [learn vim](http://vim-adventures.com/)
- The app is entirely local. The online version uses localStorage, so it should be used in only one browser
- Currently, weird things happen when you use it in multiple tabs
- There are many [known inconsistencies with vim](vim_inconsistencies.md), mostly intentional.

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
    - visual line (only within siblings)
  - keybindings for everything
  - undo!  Full history kept within a session
  - ctrl+o and ctrl+i to move through jump history
  - macros
- Extras
  - search
  - marks (not quite like vim's)
  - data export
  - different themes
  - multiple documents in online version (by visiting /documentname)
  - lazy loads data, for big documents

## SETUP: ##

#### INSTALL: ####

Assuming you have node and npm

    git clone https://github.com/WuTheFWasThat/vimflowy.git
    cd vimflowy
    npm install

#### START: ####

Just run

    npm start

And you can visit the app at `http://localhost:8080/`

#### RUN TESTS: ####

    npm test

## CONTRIBUTE ##

Please send pull requests!  Remember to write tests when appropriate!

You may contact me at [githubusername]@gmail.com as well

#### LICENSE ####

MIT: http://wuthefwasthat.mit-license.org/
