# Known inconsistencies with vim #

Feel free to report more. Most of these are intentional

- undoing operations always puts your cursor where it was.  (This is not true in vim: try going to the middle of a line and typing d0u)
- in vim, cw works like ciw, which is inconsistent/counterintuitive
- 5$ doesn't work
- 100rx will replace as many as it can
- t and T work when you use them repeatedly
- I goes to the beginning of the line, irrespective of whitespace
- yank (y) never moves the cursor (in vim, yb and yh move the cursor to the start of the yank region)
- e/b/w skip lines with only whitespace
- macros
  - redo operator (.) redoes entire macros rather than the last sequence (easy to fix, but not desired IMO)
  - not implemented using registers (weird quirk of vim IMO)

