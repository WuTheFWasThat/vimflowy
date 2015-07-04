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

# test that cursor goes back if needed
t = new TestCase ['hello world']
t.sendKeys 'v$'
t.sendKey 'esc'
t.sendKeys 'x'
t.expect ['hello worl']

# test that change works
t = new TestCase ['hello world']
t.sendKeys 'vec'
t.sendKeys 'hi'
t.sendKey 'esc'
t.expect ['hi world']
