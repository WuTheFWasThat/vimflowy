require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "delete to end", () ->
  it "works in basic case", () ->
    t = new TestCase ['some random text']
    t.sendKeys 'wD'
    t.expect ['some ']
    t.sendKeys 'D'
    t.expect ['some']
    t.sendKeys 'u'
    t.expect ['some ']
    t.sendKeys 'u'
    t.expect ['some random text']

  it "works at the end of a line", () ->
    t = new TestCase ['some random text']
    t.sendKeys '$D'
    t.expect ['some random tex']
    # paste should work
    t.sendKeys 'P'
    t.expect ['some random tetx']

describe "delete to home/end in insert mode", () ->
  it "works in basic cases", () ->
    t = new TestCase ['some random text']
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

    t = new TestCase ['some random text']
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

  it "in insert mode, ctrl+y brings you past end", () ->
    t = new TestCase ['some random text']
    t.sendKeys 'wi'
    t.sendKey 'ctrl+k'
    t.expect ['some ']
    t.sendKey 'ctrl+y'
    t.expect ['some random text']
    t.sendKey 's'
    t.expect ['some random texts']

  it "doesn't cause an undoable action when nothing happens", () ->
    t = new TestCase ['some random text']
    t.sendKeys 'x'
    t.expect ['ome random text']
    t.sendKeys '$a'
    t.sendKey 'ctrl+k'
    t.sendKey 'esc'
    t.expect ['ome random text']
    t.sendKeys 'u'
    t.expect ['some random text']

    t = new TestCase ['some random text']
    t.sendKeys '$x'
    t.expect ['some random tex']
    t.sendKeys '0i'
    t.sendKey 'ctrl+u'
    t.sendKey 'esc'
    t.expect ['some random tex']
    t.sendKeys 'u'
    t.expect ['some random text']
