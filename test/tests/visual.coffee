TestCase = require '../testcase.coffee'

describe "visual mode", () ->
  it "works with basic motions", () ->
    t = new TestCase ['hello world']
    t.sendKeys 'vwx'
    t.expect ['orld']

    t = new TestCase ['hello world']
    t.sendKeys 'vex'
    t.expect [' world']

    t = new TestCase ['hello world']
    t.sendKeys 'v$x'
    t.expect ['']

    t = new TestCase ['hello world']
    t.sendKeys 'wv3lx'
    t.expect ['hello d']

  it "keeps cursor after canceling", () ->
    t = new TestCase ['hello world']
    t.sendKeys 'vw'
    t.sendKey 'esc'
    t.sendKeys 'x'
    t.expect ['hello orld']

  it "allows cursor swap", () ->
    t = new TestCase ['hello world']
    t.sendKeys 'wv3lo3hx'
    t.expect ['held']
    t.sendKeys 'u'
    t.expect ['hello world']

  it "moves cursor back if needed", () ->
    t = new TestCase ['hello world']
    t.sendKeys 'v$'
    t.sendKey 'esc'
    t.sendKeys 'x'
    t.expect ['hello worl']
    t.sendKeys 'u'
    t.expect ['hello world']

  it "pastes", () ->
    t = new TestCase [ 'hello world' ]
    t.sendKeys 'wv$y'
    t.sendKeys 'P'
    t.expect [ 'hello worlworldd' ]
    t.sendKeys 'u'
    t.expect ['hello world']

  it "changes", () ->
    t = new TestCase ['hello world']
    t.sendKeys 'vec'
    t.sendKeys 'hi'
    t.sendKey 'esc'
    t.expect ['hi world']
    t.sendKeys 'u'
    t.expect ['hello world']

