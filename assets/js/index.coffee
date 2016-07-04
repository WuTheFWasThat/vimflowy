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


$keybindingsDiv = $('#keybindings')
$settingsDiv = $('#settings')
$modeDiv = $('#mode')

docname = window.location.pathname.split('/')[1]

changeStyle = (theme) ->
  $('body').attr('id', theme)

create_session = (doc, to_load) ->

  ####################
  # Settings
  ####################

  settings = new Settings doc.store, {mainDiv: $settingsDiv}

  changeStyle (settings.getSetting 'theme')
  $settingsDiv.find(".theme-selection").val (settings.getSetting 'theme')
  $settingsDiv.find(".theme-selection").on 'input', (e) ->
    theme = @value
    settings.setSetting 'theme', theme
    changeStyle theme

  $keybindingsDiv.toggleClass 'active', (settings.getSetting 'showKeyBindings')

  ####################
  # hotkeys and key bindings
  ####################

  hotkey_settings = settings.getSetting 'hotkeys'
  key_bindings = new KeyBindings keyDefinitions, hotkey_settings

  key_bindings.on 'applied_hotkey_settings', (hotkey_settings) ->
    settings.setSetting 'hotkeys', hotkey_settings
    View.renderHotkeysTable key_bindings
    View.renderModeTable key_bindings, session.mode, $keybindingsDiv

  ####################
  # session
  ####################

  session = new Session doc, {
    bindings: key_bindings
    settings: settings
    mainDiv: $('#view'),
    messageDiv: $('#message')
    menuDiv: $('#menu')
  }

  render_mode_info = (mode) ->
    View.renderModeTable key_bindings, mode, $keybindingsDiv
    $modeDiv.text (Modes.getMode mode).name

  render_mode_info session.mode
  session.on 'modeChange', (oldmode, newmode) ->
    render_mode_info newmode

  session.on 'toggleBindingsDiv', () ->
    $keybindingsDiv.toggleClass 'active'
    doc.store.setSetting 'showKeyBindings', $keybindingsDiv.hasClass 'active'
    View.renderModeTable key_bindings, session.mode, $keybindingsDiv

  ####################
  # plugins
  ####################

  pluginManager = new Plugins.PluginsManager session, $('#plugins')
  enabledPlugins = (settings.getSetting "enabledPlugins") || ["Marks"]
  for plugin_name in enabledPlugins
    pluginManager.enable plugin_name
  View.renderPlugins pluginManager

  pluginManager.on 'status', () ->
    View.renderPlugins pluginManager

  pluginManager.on 'enabledPluginsChange', (enabled) ->
    settings.setSetting "enabledPlugins", enabled
    View.renderPlugins pluginManager
    View.renderSession session
    # refresh hotkeys, if any new ones were added/removed
    View.renderHotkeysTable session.bindings
    View.renderModeTable session.bindings, session.mode, $keybindingsDiv

  ####################
  # load data
  ####################

  if to_load != null
    doc.load to_load
    # a bit hack.  without this, you can undo initial marks, for example
    do session.reset_history
    do session.reset_jump_history

  ####################
  # prepare dom
  ####################

  # render when ready
  $(document).ready ->
    document.title = "#{docname} - Vimflowy" unless docname is ''
    View.renderSession session

  key_handler = new KeyHandler session, key_bindings

  key_emitter = new KeyEmitter
  do key_emitter.listen
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
    # needed for safari
    $pasteHack = $('#paste-hack')
    $pasteHack.focus()
    $(document).on 'click', () ->
      # if settings menu is up, we don't want to blur (the dropdowns need focus)
      if $settingsDiv.hasClass 'hidden'
        # if user is trying to copy, we don't want to blur
        if not window.getSelection().toString()
          $pasteHack.focus()

    $(document).on 'paste', (e) ->
      e.preventDefault()
      text = (e.originalEvent || e).clipboardData.getData('text/plain')
      # TODO: deal with this better when there are multiple lines
      # maybe put in insert mode?
      lines = text.split '\n'
      for line, i in lines
        if i != 0
          do session.newLineAtCursor
        chars = line.split ''
        session.addCharsAtCursor chars
      View.renderSession session
      do session.save

    $("#settings-link").click () ->
      if session.mode == Modes.modes.SETTINGS
        session.setMode Modes.modes.NORMAL
      else
        session.setMode Modes.modes.SETTINGS

    $("#settings-nav li").click (e) ->
      tab = ($(e.target).data "tab")
      $settingsDiv.find('.tabs > li').removeClass('active')
      $settingsDiv.find('.tab-pane').removeClass('active')
      $settingsDiv.find(".tabs > li[data-tab=#{tab}]").addClass('active')
      $settingsDiv.find(".tab-pane##{tab}").addClass('active')

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
        Logger.logger.error 'Import Error', evt

    download_file = (filename, mimetype, content) ->
      exportDiv = $("#export")
      exportDiv.attr "download", filename
      exportDiv.attr "href", "data: #{mimetype};charset=utf-8,#{encodeURIComponent(content)}"
      do exportDiv[0].click
      exportDiv.attr "download", null
      exportDiv.attr "href", null

    $("#hotkeys_import").click () ->
      load_file $('#hotkeys_file_input')[0], (err, content) ->
        if err then return session.showMessage err, {text_class: 'error'}
        try
          hotkey_settings = JSON.parse content
        catch e
          return session.showMessage "Failed to parse JSON: #{e}", {text_class: 'error'}
        err = key_bindings.apply_hotkey_settings hotkey_settings
        if err
          session.showMessage err, {text_class: 'error'}
        else
          session.showMessage 'Loaded new hotkey settings!', {text_class: 'success'}

    $("#hotkeys_export").click () ->
      filename = 'vimflowy_hotkeys.json'
      content = JSON.stringify(key_bindings.hotkeys, null, 2)
      download_file filename, 'application/json', content
      session.showMessage "Downloaded hotkeys to #{filename}!", {text_class: 'success'}

    $("#hotkeys_default").click () ->
      do key_bindings.apply_default_hotkey_settings
      session.showMessage "Loaded defaults!", {text_class: 'success'}

    $("#data_import").click () ->
      load_file $('#import-file :file')[0], (err, content, filename) ->
        if err then return session.showMessage err, {text_class: 'error'}
        mimetype = utils.mimetypeLookup filename
        if session.importContent content, mimetype
          session.showMessage 'Imported!', {text_class: 'success'}
          session.setMode Modes.modes.NORMAL
        else
          session.showMessage 'Import failed due to parsing issue', {text_class: 'error'}

    export_type = (type) ->
      session.showMessage 'Exporting...'
      filename = if docname is '' then "vimflowy.#{type}" else "#{docname}.#{type}"
      # Infer mimetype from file extension
      mimetype = utils.mimetypeLookup filename
      content = session.exportContent mimetype
      download_file filename, mimetype, content
      session.showMessage "Exported to #{filename}!", {text_class: 'success'}

    $("#data_export_json").click (export_type.bind @, 'json')
    $("#data_export_plain").click (export_type.bind @, 'txt')

  $(window).unload () ->
    do session.exit


if chrome?.storage?.sync
  Logger.logger.info 'using chrome storage'

  # TODO
  # datastore = new DataStore.ChromeStorageLazy

  datastore = new DataStore.InMemory
  doc = new Document datastore
  chrome.storage.sync.get 'save', (results) ->
    create_session doc, (results.save or constants.default_data)

    # save every 5 seconds
    setInterval (() ->
      chrome.storage.sync.set {
        'save': doc.serialize()
      }, () ->
        # TODO have whether saved visualized
        Logger.logger.info 'Saved'
    ), 5000

else if localStorage?
  datastore = new DataStore.LocalStorageLazy docname
  doc = new Document datastore

  to_load = null
  if (do datastore.getLastSave) == 0
    to_load = constants.default_data

  create_session doc, to_load
else
  alert('You need local storage support for data to be persisted!')
  datastore = new DataStore.InMemory
  doc = new Document datastore
  create_session doc, constants.default_data

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
