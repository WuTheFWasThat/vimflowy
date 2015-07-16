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

    @view = new View @data
    @view.render = -> return
    @keybinder = new KeyBindings @view
    @register = @view.register

  sendKeys: (keys) ->
    for key in keys
      @keybinder.handleKey key

  sendKey: (key) ->
    @sendKeys [key]

  expectDeepEqual: (actual, expected) ->
    assert.deepEqual actual, expected,
      "Expected \n #{JSON.stringify(actual, null, 2)}" +
      "To match \n #{JSON.stringify(expected, null, 2)}"

  expect: (expected) ->
    serialized = @data.serialize @data.root, true
    @expectDeepEqual serialized.children, expected

  setRegister: (value) ->
    @register.deserialize value

  expectRegister: (expected) ->
    current = do @register.serialize
    @expectDeepEqual current, expected

  expectRegisterType: (expected) ->
    current = do @register.serialize
    @expectDeepEqual current.type, expected

  expectExport: (fileExtension, expected) ->
    export_ = @view.exportContent fileExtension
    assert.equal export_, expected,
      "Expected \n#{export_}\n To match \n#{expected}\n!"

  expectMarks: (expected) ->
    marks = do @view.data.store.getAllMarks
    @expectDeepEqual marks, expected

module.exports = TestCase
