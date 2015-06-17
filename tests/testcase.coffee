require 'coffee-script/register'
assert = require 'assert'

dataStore = require '../assets/js/datastore.coffee'
Data = require '../assets/js/data.coffee'
View = require '../assets/js/view.coffee'
KeyBindings = require '../assets/js/keyBindings.coffee'
Register = require '../assets/js/register.coffee'

class TestCase
  constructor: (serialized = ['']) ->
    @store = new dataStore.InMemory
    @data = new Data @store
    @data.load
      line: ''
      children: serialized

    @view = new View null, @data
    @view.render = -> return
    @keybinder = new KeyBindings @view
    @register = @view.register

  sendKeys: (keys) ->
    for key in keys
      @keybinder.handleKey key

  sendKey: (key) ->
    @sendKeys [key]

  expect: (expected) ->
    serialized = do @data.serialize
    assert.deepEqual serialized.children, expected,
      'Expected \n' + JSON.stringify(serialized.children, null, 2) +
      'To match \n' + JSON.stringify(expected, null, 2) +
      '\n!'

  setRegister: (value) ->
    @register.deserialize value

  expectRegister: (expected) ->
    current = do @register.serialize
    assert.deepEqual current, expected,
      'Expected \n' + JSON.stringify(current, null, 2) +
      'To match \n' + JSON.stringify(expected, null, 2) +
      '\n!'

  expectExport: (fileExtension, expected) ->
    export_ = @data.export "vimflowy.#{fileExtension}"
    assert.equal export_, expected,
      "Expected \n#{export_}\n To match \n#{expected}\n!"

module.exports = TestCase
