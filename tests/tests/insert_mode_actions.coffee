require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# tricky case - makes sure redoing actions puts cursor in good spot
new TestCase ['bug reproduce'], (t) ->
  t.sendKeys 'i'
  t.sendKey 'ctrl+e' # put cursor at end, this will be remembered by view
  t.sendKey 'ctrl+w'
  t.expect ['bug ']
  t.sendKey 'ctrl+w'
  t.expect ['']
  t.sendKey 'ctrl+y'
  t.expect ['bug ']
  t.sendKey 'ctrl+y'
  t.expect ['bug bug ']
  t.sendKey 'esc'
  t.sendKey 'u'
  t.expect ['bug reproduce']
  # even though we remembered cursor to be past e, it gets moved back,
  # since we're now in normal mode
  t.sendKey 'x'
  t.expect ['bug reproduc']
