require 'blanket'
require 'coffee-script/register'
assert = require 'assert'
_ = require 'lodash'
fs = require 'fs'
path = require 'path'

DataStore = require '../assets/js/datastore'
Document = (require '../assets/js/document').Document
Session = require '../assets/js/session'
for file in fs.readdirSync path.resolve __dirname, '../assets/js/definitions'
  if (file.match /.*\.js$/) or (file.match /.*\.coffee$/)
    require path.join '../assets/js/definitions', file
KeyDefinitions = require '../assets/js/keyDefinitions'
KeyBindings = require '../assets/js/keyBindings'
KeyHandler = require '../assets/js/keyHandler'
Register = require '../assets/js/register'
Settings = require '../assets/js/settings'
Logger = require '../assets/js/logger'
Plugins = require '../assets/js/plugins'

Logger.logger.setStream Logger.STREAM.QUEUE
afterEach 'empty the queue', () ->
  do Logger.logger.empty

class TestCase
  constructor: (serialized = ['']) ->
    @store = new DataStore.InMemory
    @document = new Document @store

    @settings =  new Settings @store

    # will have default bindings
    keyBindings = new KeyBindings (do KeyDefinitions.clone), @settings

    @session = new Session @document, {bindings: keyBindings}

    @keyhandler = new KeyHandler @session, keyBindings
    @register = @session.register

    @pluginManager = new Plugins.PluginsManager @session
    for name of do Plugins.all
      @pluginManager.enable name

    # this must be *after* plugin loading because of plugins with state
    # e.g. marks needs the database to have the marks loaded
    @document.load serialized
    do @session.reset_history
    do @session.reset_jump_history

  _expectDeepEqual: (actual, expected, message) ->
    if not _.isEqual actual, expected
      do Logger.logger.flush
      console.error "
        \nExpected:
        \n#{JSON.stringify(expected, null, 2)}
        \nBut got:
        \n#{JSON.stringify(actual, null, 2)}
      "
      throw new Error message

  _expectEqual: (actual, expected, message) ->
    if actual != expected
      do Logger.logger.flush
      console.error "
        \nExpected:
        \n#{expected}
        \nBut got:
        \n#{actual}
      "
      throw new Error message

  sendKeys: (keys) ->
    for key in keys
      @keyhandler.handleKey key
    return @

  sendKey: (key) ->
    @sendKeys [key]
    return @

  import: (content, mimetype) ->
    @session.importContent content, mimetype

  expect: (expected) ->
    serialized = @document.serialize @document.root, {pretty: true}
    @_expectDeepEqual serialized.children, expected, "Unexpected serialized content"
    return @

  expectViewRoot: (expected) ->
    @_expectEqual @session.viewRoot.id, expected, "Unexpected view root"
    return @

  expectCursor: (row, col) ->
    @_expectEqual @session.cursor.row.id, row, "Unexpected cursor row"
    @_expectEqual @session.cursor.col, col, "Unexpected cursor col"
    return @

  expectJumpIndex: (index, historyLength = null) ->
    @_expectEqual @session.jumpIndex, index, "Unexpected jump index"
    if historyLength != null
      @_expectEqual @session.jumpHistory.length, historyLength, "Unexpected jump history length"
    return @

  expectNumMenuResults: (num_results) ->
    @_expectEqual @session.menu.results.length, num_results, "Unexpected number of results"
    return @

  setRegister: (value) ->
    @register.deserialize value
    return @

  expectRegister: (expected) ->
    current = do @register.serialize
    @_expectDeepEqual current, expected, "Unexpected register content"
    return @

  expectRegisterType: (expected) ->
    current = do @register.serialize
    @_expectDeepEqual current.type, expected, "Unexpected register type"
    return @

  expectExport: (fileExtension, expected) ->
    export_ = @session.exportContent fileExtension
    @_expectEqual export_, expected, "Unexpected export content"
    return @

module.exports = TestCase
