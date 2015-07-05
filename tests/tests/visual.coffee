require 'coffee-script/register'
TestCase = require '../testcase.coffee'

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

# movement in visual persists
t = new TestCase ['hello world']
t.sendKeys 'vw'
t.sendKey 'esc'
t.sendKeys 'x'
t.expect ['hello orld']

# test o
t = new TestCase ['hello world']
t.sendKeys 'wv3lo3hx'
t.expect ['held']
t.sendKeys 'u'
t.expect ['hello world']

# test that cursor goes back if needed
t = new TestCase ['hello world']
t.sendKeys 'v$'
t.sendKey 'esc'
t.sendKeys 'x'
t.expect ['hello worl']
t.sendKeys 'u'
t.expect ['hello world']

t = new TestCase [ 'hello world' ]
t.sendKeys 'wv$y'
t.sendKeys 'P'
t.expect [ 'hello worlworldd' ]
t.sendKeys 'u'
t.expect ['hello world']

# test that change works
t = new TestCase ['hello world']
t.sendKeys 'vec'
t.sendKeys 'hi'
t.sendKey 'esc'
t.expect ['hi world']
t.sendKeys 'u'
t.expect ['hello world']

# test repeat
t = new TestCase [ '1234567' ]
t.sendKeys 'vllx'
t.expect [ '4567' ]
t.sendKeys '.'
t.expect [ '7' ]
