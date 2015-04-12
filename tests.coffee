require 'coffee-script/register'
assert = require 'assert'

Data = require './assets/js/data.coffee'
View = require './assets/js/view.coffee'
KeyBindings = require './assets/js/keyBindings.coffee'

class TestCase
  constructor: () ->
    @data = new Data
    @view = new View null, @data
    @view.render = -> return
    @view.renderHelper = -> return
    @view.drawRow = -> return
    @keybinder = new KeyBindings null, null, @view

  sendKeys: (keys) ->
    for key in keys
      @sendKey key

  sendKey: (key) ->
    @keybinder.handleKey key

  expect: (expected) ->
    serialized = do @data.serialize
    assert.deepEqual serialized.children, expected

t = new TestCase
t.sendKey 'i'
t.sendKeys 'hello world'
t.expect ['hello world']

t.sendKey 'esc'
t.sendKeys 'xxxsu'
t.expect ['hello wu']

t.sendKey 'esc'
t.sendKeys 'uuuuu'
t.expect ['hello world']

t.sendKey 'esc'
for i in [0..4]
  t.sendKey 'ctrl+r'
t.expect ['hello wu']
