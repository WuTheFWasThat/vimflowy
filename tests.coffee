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
t.sendKey 'esc'
t.expect ['hello world']

t.sendKeys 'xxxsu'
t.expect ['hello wu']

t.sendKey 'esc'
t.sendKeys 'uuuuu'
t.expect ['hello world']

t.sendKey 'esc'
for i in [0..4]
  t.sendKey 'ctrl+r'
t.expect ['hello wu']

t.sendKeys '0x'
t.expect ['ello wu']

t.sendKeys '$x'
t.expect ['ello w']

# delete on the last character should send the cursor back one
t.sendKeys 'hx'
t.expect ['ellow']

t.sendKeys 'Iy'
t.sendKey 'esc'
t.expect ['yellow']

t.sendKeys 'Ay'
t.sendKey 'esc'
t.expect ['yellowy']

t.sendKeys 'a purple'
t.sendKey 'esc'
t.expect ['yellowy purple']

t = new TestCase
t.sendKey 'i'
t.sendKeys 'hello world'
t.sendKey 'esc'
t.expect ['hello world']

# make sure delete and then undo doesn't move the cursor
t.sendKeys 'hhxux'
t.expect ['hello wold']

# delete on last character should work
t.sendKeys '$dl'
t.expect ['hello wol']
# and it should send the cursor back one
t.sendKey 'x'
t.expect ['hello wo']
# replace
# t.sendKeys 'ru'
# t.expect ['hello wu']
# hitting left should send the cursor back one more
t.sendKey 'left'
t.sendKeys 'x'
t.expect ['hello o']

#    RIGHT:
#      display: 'Move cursor right'
#      key: 'l'
#      motion: true
#    CHANGE:
#      display: 'Change (operator)'
#      key: 'c'
