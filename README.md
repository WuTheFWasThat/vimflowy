# vimflowy?? #

## TODO ##

implement y and p
implement ctrl+o

make undo work properly for sequences?

## KNOWN ISSUES: ##

Firstly, I have many known inconsistencies with vi.  Many are intentional.  For example:
- undoing operations puts your cursor where it was.  (This is not true in vim: try going to the middle of a line and typing d0u)
- b/e/w all treat all non-whitespace as part of a word
- yank (y) never moves the cursor (in vim, yb and yh move the cursor to the start of the yank region)
- in vim, cw works like ciw, which is inconsistent/counterintuitive
- 5$ doesn't work
- 100rx will replace as many as it can
- t and T work when you use them repeatedly

Ones which should probably be fixed
- undoing does not undo entire blocks of transactions (i.e. insert mode + blah + esc does not undo atomically, neither does 5de)

## CONTRIBUTE: ##

