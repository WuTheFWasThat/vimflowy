###
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage/chrome storage (fall back to plain in-memory datastructures)
- initialize objects (session, settings, etc.) with relevant divs
###

constants = require './constants.coffee'
errors = require './errors.coffee'
utils = require './utils.coffee'
Logger = require './logger.coffee'

Modes = require './modes.coffee'
KeyEmitter = require './keyEmitter.coffee'
KeyHandler = require './keyHandler.coffee'
DataStore = require './datastore.coffee'
Document = (require './document.coffee').Document
Settings = require './settings.coffee'
Plugins = require './plugins.coffee'
Session = require './session.coffee'
View = require './view.coffee'

keyDefinitions = require './keyDefinitions.coffee'
# load all definitions
require './definitions/*.coffee', {mode: 'expand'}
# load all plugins
require '../../plugins/**/*.js', {mode: 'expand'}
require '../../plugins/**/*.coffee', {mode: 'expand'}
KeyBindings = require './keyBindings.coffee'

session = null
create_session = (document, to_load) ->

  settings = new Settings document.store, {mainDiv: $('#settings'), keybindingsDiv: $('#keybindings')}
  do settings.loadRenderSettings

  key_bindings = new KeyBindings keyDefinitions, settings, {modebindingsDiv: $('#keybindings')}

  session = new Session document, {
    bindings: key_bindings
    settings: settings
    mainDiv: $('#view'),
    settingsDiv: $('#settings')
    messageDiv: $('#message')
    keybindingsDiv: $('#keybindings')
    modeDiv: $('#mode')
    menuDiv: $('#menu')
  }

  pluginManager = new Plugins.PluginsManager session, $('#plugins')
  enabledPlugins = (session.settings.getSetting "enabledPlugins") || ["Marks"]
  for plugin_name in enabledPlugins
    pluginManager.enable plugin_name

  View.initRenderSession session

  if to_load != null
    document.load to_load
    # otherwise, you can undo initial marks, for example
    do session.reset_history
    do session.reset_jump_history

  $(document).ready ->
    do session.hideSettings
    View.renderSession session

  # needed for safari
  $('#paste-hack').focus()
  $(document).on('click', () ->
    # if settings menu is up, we don't want to blur (the dropdowns need focus)
    if $('#settings').hasClass 'hidden'
      # if user is tryign to copy, we don't want to blur
      if not window.getSelection().toString()
        $('#paste-hack').focus()
  )

  $(document).on('paste', (e) ->
      e.preventDefault()
      text = (e.originalEvent || e).clipboardData.getData('text/plain')
      # TODO: deal with this better when there are multiple lines
      # maybe put in insert mode?
      lines = text.split '\n'
      for line, i in lines
        if i != 0
          do session.newLineAtCursor
        chars = line.split ''
        options = {}
        if session.mode == Modes.modes.INSERT
          options.cursor = {pastEnd: true}
        session.addCharsAtCursor chars, options
      View.renderSession session
      do session.save
  )

  key_emitter = new KeyEmitter
  do key_emitter.listen
  key_handler = new KeyHandler session, key_bindings
  key_emitter.on 'keydown', (key) ->
    handled = key_handler.handleKey key
    if handled
      View.renderSession session
    return handled

  session.on 'importFinished', () ->
    View.renderSession session

  # expose globals, for debugging
  window.Modes = Modes
  window.session = session
  window.key_handler = key_handler
  window.key_emitter = key_emitter
  window.key_bindings = key_bindings

  $(document).ready ->
    $("#settings-link").click () =>
      do session.settingsToggle

    $("#settings-nav li").click (e) ->
      session.selectSettingsTab ($(e.target).data "tab")

    load_file = (filesDiv, cb) ->
        file = filesDiv.files[0]
        if not file?
            return cb 'No file selected for import!'
        session.showMessage 'Reading in file...'
        reader = new FileReader()
        reader.readAsText file, "UTF-8"
        reader.onload = (evt) ->
            content = evt.target.result
            cb null, content, file.name
        reader.onerror = (evt) ->
            cb 'Import failed due to file-reading issue'
            console.log 'Import Error', evt

    download_file = (filename, mimetype, content) ->
        exportDiv = $("#export")
        exportDiv.attr "download", filename
        exportDiv.attr "href", "data: #{mimetype};charset=utf-8,#{encodeURIComponent(content)}"
        do exportDiv[0].click
        exportDiv.attr "download", null
        exportDiv.attr "href", null

    $("#hotkeys_import").click () =>
        load_file $('#hotkeys_file_input')[0], (err, content) ->
            if err then return session.showMessage err, {text_class: 'error'}
            try
                hotkey_settings = JSON.parse content
            catch e
                return session.showMessage "Failed to parse JSON: #{e}", {text_class: 'error'}
            err = key_bindings.apply_hotkey_settings hotkey_settings
            if err then return session.showMessage err, {text_class: 'error'}
            key_bindings.save_settings hotkey_settings
            key_bindings.renderModeTable session.mode # TODO: do this elsewhere?
            session.showMessage 'Loaded new hotkey settings!', {text_class: 'success'}

    $("#hotkeys_export").click () =>
        filename = 'vimflowy_hotkeys.json'
        content = JSON.stringify(key_bindings.hotkeys, null, 2)
        download_file filename, 'application/json', content
        session.showMessage "Downloaded hotkeys to #{filename}!", {text_class: 'success'}

    $("#hotkeys_default").click () =>
        do key_bindings.apply_default_hotkey_settings
        key_bindings.renderModeTable session.mode # TODO: do this elsewhere?
        session.showMessage "Loaded defaults!", {text_class: 'success'}

    $("#data_import").click () =>
        load_file $('#import-file :file')[0], (err, content, filename) ->
            if err then return session.showMessage err, {text_class: 'error'}
            mimetype = utils.mimetypeLookup filename
            if session.importContent content, mimetype
                session.showMessage 'Imported!', {text_class: 'success'}
                do session.hideSettings
            else
                session.showMessage 'Import failed due to parsing issue', {text_class: 'error'}

    export_type = (type) ->
      session.showMessage 'Exporting...'
      filename = 'vimflowy.' + type
      # Infer mimetype from file extension
      mimetype = utils.mimetypeLookup filename
      content = session.exportContent mimetype
      download_file filename, mimetype, content
      session.showMessage "Exported to #{filename}!", {text_class: 'success'}

    $("#data_export_json").click (export_type.bind @, 'json')
    $("#data_export_plain").click (export_type.bind @, 'txt')

  $(window).unload () =>
    do session.exit


if chrome?.storage?.sync
  Logger.logger.info 'using chrome storage'

  # TODO
  # datastore = new DataStore.ChromeStorageLazy

  datastore = new DataStore.InMemory
  document = new Document datastore
  chrome.storage.sync.get 'save', (results) ->
    create_session document, (results.save or constants.default_data)

    # save every 5 seconds
    setInterval (() ->
      chrome.storage.sync.set {
        'save': document.serialize()
      }, () ->
        # TODO have whether saved visualized
        Logger.logger.info 'Saved'
    ), 5000

else if localStorage?
  docname = window.location.pathname.split('/')[1]
  datastore = new DataStore.LocalStorageLazy docname
  document = new Document datastore

  to_load = null
  if (do datastore.getLastSave) == 0
    to_load = constants.default_data

  create_session document, to_load
else
  alert('You need local storage support for data to be persisted!')
  datastore = new DataStore.InMemory
  document = new Document datastore
  create_session document, constants.default_data

window.onerror = (msg, url, line, col, err) ->
    Logger.logger.error "Caught error: '#{msg}' from  #{url}:#{line}"
    if err != undefined
        Logger.logger.error "Error: ", err, err.stack

    if err instanceof errors.DataPoisoned
        # no need to alert, already alerted
        return

    alert "
      An error was caught.  Please refresh the page to avoid weird state. \n\n
      Please help out vimflowy and report the bug!
      Simply open the javascript console, save the log as debug information,
      and send it to wuthefwasthat@gmail.com with a brief description of what happened.
      \n\n
      ERROR:\n\n
      #{msg}\n\n
      #{err}\n\n
      #{err.stack}
    "
