# vimflowy?? #

## KNOWN ISSUES: ##

Firstly, I have many known inconsistencies with vi.  Many are intentional.  For example:
- undoing operations puts your cursor where it was.  (This is not true in vim: try going to the middle of a line and typing d0u)
- b/e/w all treat all non-whitespace as part of a word
- cw works like ciw in vim, which is inconsistent/counterintuitive

## CONTRIBUTE: ##

