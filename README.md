# vimflowy

This is a productivity tool which draws great inspiration from workflowy and vim

Try it out [here](https://vimflowy.bitballoon.com)!

# NOTES #

- The app is entirely local - the storage is localStorage, so it should be used in only one browser
- Currently, weird things happen when you use it in multiple tabs

## KNOWN ISSUES: ##

- e/b/w don't cross onto next line

Known (intentional) inconsistencies with vi (WONTFIX without further discussion):
- undoing operations always puts your cursor where it was.  (This is not true in vim: try going to the middle of a line and typing d0u)
- in vim, cw works like ciw, which is inconsistent/counterintuitive
- 5$ doesn't work
- 100rx will replace as many as it can
- t and T work when you use them repeatedly
- I goes to the beginning of the line, irrespective of whitespace
- yank (y) never moves the cursor (in vim, yb and yh move the cursor to the start of the yank region)
- macros
  - redo operator (.) redoes entire macros rather than the last sequence (easy to fix, but not desired IMO)
  - not implemented using registers (weird quirk of vim IMO)

## CONTRIBUTE: ##

Please send pull requests!
You may contact me at [githubusername]@gmail.com as well

## LICENSE ##

MIT: http://wuthefwasthat.mit-license.org/
