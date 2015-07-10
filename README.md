# vimflowy

This is a productivity tool which draws great inspiration from workflowy and vim

Try it out [here](https://vimflowy.bitballoon.com)!

(Video coming eventually...)

## FEATURES ##

- Workflowy features
  - bullets, sub-bullets
  - collapsing
  - zooming
- Vim features
  - modal editing
    - insert and normal mode
    - visual mode (only within a line)
    - visual line (only within siblings)
  - keybindings for everything
  - undo!  Full history kept within a session
  - macros
- Extras
  - (inefficient) search
  - data export
  - different themes
  - lazy loads data, for big documents

## NOTES ##

- The app is entirely local - the storage is localStorage, so it should be used in only one browser
- Currently, weird things happen when you use it in multiple tabs
- There are many [known inconsistencies with vim](vim_inconsistencies.md), mostly intentional.

## SET UP: ##

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

## CONTRIBUTE: ##

Please send pull requests!  Remember to write tests when appropriate!

You may contact me at [githubusername]@gmail.com as well

## LICENSE ##

MIT: http://wuthefwasthat.mit-license.org/
