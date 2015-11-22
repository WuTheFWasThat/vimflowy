# Known inconsistencies with vim #

There are some obvious huge differences like search and marks behavior.
This catalogs some more subtle differences.  Most have been entirely intentional.

If you feel any of them make vimflowy feel significantly less familiar, contact me and I'll take it into consideration.
And feel free to report more!

- When using `dd` to delete blocks, the line(s) are "cloned" rather than copied, for efficiency reasons.
  The typical use case for dd is to move things around, in which case it doesn't matter.  It only matters when pasting twice.
  For example, if you delete a block, paste it once, change the pasted block, and paste again, the second paste will contain the modifications
  and be synced with the first paste.  In cases where you need a copy, use yank instead.
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

