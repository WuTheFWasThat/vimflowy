require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase ['hello world'], {}, (t) ->
  t.sendKeys 'vwx'
  t.expect ['orld']

new TestCase ['hello world'], {}, (t) ->
  t.sendKeys 'vex'
  t.expect [' world']

new TestCase ['hello world'], {}, (t) ->
  t.sendKeys 'v$x'
  t.expect ['']

new TestCase ['hello world'], {}, (t) ->
  t.sendKeys 'wv3lx'
  t.expect ['hello d']

new TestCase ['hello world'], { name: "movement in visual persists" }, (t) ->
  t.sendKeys 'vw'
  t.sendKey 'esc'
  t.sendKeys 'x'
  t.expect ['hello orld']

new TestCase ['hello world'], { name: "test o" }, (t) ->
  t.sendKeys 'wv3lo3hx'
  t.expect ['held']
  t.sendKeys 'u'
  t.expect ['hello world']

new TestCase ['hello world'], { name: "test that cursor goes back if needed" }, (t) ->
  t.sendKeys 'v$'
  t.sendKey 'esc'
  t.sendKeys 'x'
  t.expect ['hello worl']
  t.sendKeys 'u'
  t.expect ['hello world']

new TestCase [ 'hello world' ], {}, (t) ->
  t.sendKeys 'wv$y'
  t.sendKeys 'P'
  t.expect [ 'hello worlworldd' ]
  t.sendKeys 'u'
  t.expect ['hello world']

new TestCase ['hello world'], { name: "test that change works" }, (t) ->
  t.sendKeys 'vec'
  t.sendKeys 'hi'
  t.sendKey 'esc'
  t.expect ['hi world']
  t.sendKeys 'u'
  t.expect ['hello world']

new TestCase [ '1234567' ], { name: "test repeat" }, (t) ->
  t.sendKeys 'vllx'
  t.expect [ '4567' ]
  t.sendKeys '.'
  t.expect [ '7' ]

new TestCase [ '1234' ], { name: "test repeat" }, (t) ->
  t.sendKeys 'xvly'
  t.expect [ '234' ]
  t.sendKeys '.'
  t.expect [ '24' ]
