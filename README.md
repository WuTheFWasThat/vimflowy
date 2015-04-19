# vimflowy?? #

## TODO ##

implement # to repeat
implement f/F/t/T
implement y and p
implement ctrl+o

make undo work properly for sequences?

## KNOWN ISSUES: ##

Firstly, I have many known inconsistencies with vi.  Many are intentional.  For example:
- undoing operations puts your cursor where it was.  (This is not true in vim: try going to the middle of a line and typing d0u)
- b/e/w all treat all non-whitespace as part of a word
- yank (y) never moves the cursor (in vim, yb and yh move the cursor to the start of the yank region)
- cw works like ciw in vim, which is inconsistent/counterintuitive

Ones which should probably be fixed
- undoing does not undo entire blocks of transactions (i.e. insert mode + blah + esc does not undo atomically, neither does 5de)

## CONTRIBUTE: ##

