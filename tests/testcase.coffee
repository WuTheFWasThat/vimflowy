require 'coffee-script/register'
assert = require 'assert'

dataStore = require '../assets/js/datastore.coffee'
Data = require '../assets/js/data.coffee'
View = require '../assets/js/view.coffee'
KeyBindings = require '../assets/js/keyBindings.coffee'
KeyHandler = require '../assets/js/keyHandler.coffee'
Register = require '../assets/js/register.coffee'

class TestCase
  constructor: (serialized = ['']) ->
    @store = new dataStore.InMemory
    @data = new Data @store
    @data.load
      text: ''
      children: serialized

    @view = new View @data
    @view.render = -> return
    @keyhandler = new KeyHandler @view, new KeyBindings
    @register = @view.register

  _expectDeepEqual: (actual, expected) ->
    assert.deepEqual actual, expected,
      "Expected \n #{JSON.stringify(expected, null, 2)}" +
      "But got \n #{JSON.stringify(actual, null, 2)}"

  sendKeys: (keys) ->
    for key in keys
      @keyhandler.handleKey key
    return @

  sendKey: (key) ->
    @sendKeys [key]
    return @

  import: (content, mimetype) ->
    @view.importContent content, mimetype

  expect: (expected) ->
    serialized = @data.serialize @data.root, true
    @_expectDeepEqual serialized.children, expected
    return @

  expectViewRoot: (expected) ->
    assert.equal @data.viewRoot, expected
    return @

  expectCursor: (row, col) ->
    assert.equal @view.cursor.row, row
    assert.equal @view.cursor.col, col
    return @

  expectJumpIndex: (index, historyLength = null) ->
    assert.equal @view.jumpIndex, index
    if historyLength != null
      assert.equal @view.jumpHistory.length, historyLength
    return @

  setRegister: (value) ->
    @register.deserialize value
    return @

  expectRegister: (expected) ->
    current = do @register.serialize
    @_expectDeepEqual current, expected
    return @

  expectRegisterType: (expected) ->
    current = do @register.serialize
    @_expectDeepEqual current.type, expected
    return @

  expectExport: (fileExtension, expected) ->
    export_ = @view.exportContent fileExtension
    assert.equal export_, expected,
      "Expected \n#{export_}\n To match \n#{expected}\n!"
    return @

  expectMarks: (expected) ->
    marks = do @view.data.store.getAllMarks
    @_expectDeepEqual marks, expected
    return @

module.exports = TestCase
