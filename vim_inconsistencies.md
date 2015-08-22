# Known inconsistencies with vim #

There are some obvious huge differences like search and marks behavior.
This catalogs some more subtle differences.  Most have been entirely intentional.

If you feel any of them make vimflowy feel significantly less familiar, contact me and I'll take it into consideration.
And feel free to report more!

- when deleting an entire line (or multiple lines), pasting it only works once.  this is for efficiency reasons.  if the line is very large
  then one must copy (which takes awhile).  the typical use case is to move things around.  when another copy is needed, just yank
- 5$ doesn't work
- I goes to the beginning of the line, irrespective of whitespace

- undoing operations always puts your cursor where it was.  (This is not true in vim: try going to the middle of a line and typing d0u)
- in vim, cw works like ciw, which is inconsistent/counterintuitive
- 100rx will replace as many as it can
- t and T work when you use them repeatedly
- yank (y) never moves the cursor (in vim, yb and yh move the cursor to the start of the yank region)
- e/b/w skip lines with only whitespace
- macros
  - redo operator (.) redoes entire macros rather than the last sequence (easy to fix, but not desired IMO)
  - not implemented using registers

