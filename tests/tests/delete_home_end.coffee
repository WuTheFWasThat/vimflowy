require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase ['some random text'], {}, (t) ->
  t.sendKeys 'wD'
  t.expect ['some ']
  t.sendKeys 'D'
  t.expect ['some']
  t.sendKeys 'u'
  t.expect ['some ']
  t.sendKeys 'u'
  t.expect ['some random text']

new TestCase ['some random text'], {}, (t) ->
  t.sendKeys '$D'
  t.expect ['some random tex']
  # paste should work
  t.sendKeys 'P'
  t.expect ['some random tetx']

new TestCase ['some random text'], { name: "in insert mode" }, (t) ->
  t.sendKeys 'wi'
  t.sendKey 'ctrl+k'
  t.expect ['some ']
  t.sendKey 'ctrl+u'
  t.expect ['']
  t.sendKey 'ctrl+y'
  t.expect ['some ']
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect ['some random text']

new TestCase ['some random text'], { name: "in insert mode" }, (t) ->
  t.sendKeys 'wi'
  t.sendKey 'ctrl+u'
  t.expect ['random text']
  t.sendKey 'ctrl+k'
  t.expect ['']
  t.sendKey 'ctrl+y'
  t.expect ['random text']
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect ['some random text']

new TestCase ['some random text'], { name: "in insert mode, ctrl+y brings you past end?" }, (t) ->
  t.sendKeys 'wi'
  t.sendKey 'ctrl+k'
  t.expect ['some ']
  t.sendKey 'ctrl+y'
  t.expect ['some random text']
  t.sendKey 's'
  t.expect ['some random texts']

new TestCase ['some random text'], { name: "not undoable when nothing" }, (t) ->
  t.sendKeys 'x'
  t.expect ['ome random text']
  t.sendKeys '$a'
  t.sendKey 'ctrl+k'
  t.sendKey 'esc'
  t.expect ['ome random text']
  t.sendKeys 'u'
  t.expect ['some random text']
