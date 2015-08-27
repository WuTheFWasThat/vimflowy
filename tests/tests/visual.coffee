require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase ['hello world'], (t) ->
  t.sendKeys 'vwx'
  t.expect ['orld']

new TestCase ['hello world'], (t) ->
  t.sendKeys 'vex'
  t.expect [' world']

new TestCase ['hello world'], (t) ->
  t.sendKeys 'v$x'
  t.expect ['']

new TestCase ['hello world'], (t) ->
  t.sendKeys 'wv3lx'
  t.expect ['hello d']

# movement in visual persists
new TestCase ['hello world'], (t) ->
  t.sendKeys 'vw'
  t.sendKey 'esc'
  t.sendKeys 'x'
  t.expect ['hello orld']

# test o
new TestCase ['hello world'], (t) ->
  t.sendKeys 'wv3lo3hx'
  t.expect ['held']
  t.sendKeys 'u'
  t.expect ['hello world']

# test that cursor goes back if needed
new TestCase ['hello world'], (t) ->
  t.sendKeys 'v$'
  t.sendKey 'esc'
  t.sendKeys 'x'
  t.expect ['hello worl']
  t.sendKeys 'u'
  t.expect ['hello world']

new TestCase [ 'hello world' ], (t) ->
  t.sendKeys 'wv$y'
  t.sendKeys 'P'
  t.expect [ 'hello worlworldd' ]
  t.sendKeys 'u'
  t.expect ['hello world']

# test that change works
new TestCase ['hello world'], (t) ->
  t.sendKeys 'vec'
  t.sendKeys 'hi'
  t.sendKey 'esc'
  t.expect ['hi world']
  t.sendKeys 'u'
  t.expect ['hello world']

# test repeat
new TestCase [ '1234567' ], (t) ->
  t.sendKeys 'vllx'
  t.expect [ '4567' ]
  t.sendKeys '.'
  t.expect [ '7' ]

# test repeat
new TestCase [ '1234' ], (t) ->
  t.sendKeys 'xvly'
  t.expect [ '234' ]
  t.sendKeys '.'
  t.expect [ '24' ]
