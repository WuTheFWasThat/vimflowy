###
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load data from localStorage or chrome storage, or just use in-memory datastructures
- initialize objects (view, settings, etc.) with relevant divs
###

view = null
create_view = (data) ->

  settings = new Settings data.store, {mainDiv: $('#settings'), keybindingsDiv: $('#keybindings')}
  do settings.loadRenderSettings
  window?.setSetting = settings.setSetting.bind settings # For enabling debugging

  keyBindings = new KeyBindings settings, {modebindingsDiv: $('#keybindings')}

  view = new View data, {
    bindings: keyBindings
    settings: settings
    mainDiv: $('#view'),
    settingsDiv: $('#settings')
    messageDiv: $('#message')
    keybindingsDiv: $('#keybindings')
    modeDiv: $('#mode')
    menuDiv: $('#menu')
  }

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
      # maye put in insert mode?
      lines = text.split '\n'
      for line, i in lines
        if i != 0
          do view.newLineAtCursor
        chars = line.split ''
        options = {}
        if view.mode == constants.MODES.INSERT
          options.cursor = {pastEnd: true}
        view.addCharsAtCursor chars, options
      do view.render
      do view.save
  )

  key_emitter = new KeyEmitter
  do key_emitter.listen
  keyhandler = new KeyHandler view, keyBindings
  key_emitter.on 'keydown', keyhandler.handleKey.bind(keyhandler)

  $(document).ready ->
    do view.hideSettings
    do view.render

    $("#settings-link").click () =>
      do view.settingsToggle

    load_file = (filesDiv, cb) ->
        file = filesDiv.files[0]
        if not file?
            return cb 'No file selected for import!'
        view.showMessage 'Reading in file...'
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
            if err then return view.showMessage err, {text_class: 'error'}
            try
                hotkey_settings = JSON.parse content
            catch e
                return view.showMessage "Failed to parse JSON: #{e}", {text_class: 'error'}
            err = keyBindings.apply_hotkey_settings hotkey_settings
            if err then return view.showMessage err, {text_class: 'error'}
            keyBindings.save_settings hotkey_settings
            keyBindings.renderModeTable view.mode # TODO: do this elsewhere?
            view.showMessage 'Loaded new hotkey settings!', {text_class: 'success'}

    $("#hotkeys_export").click () =>
        filename = 'vimflowy_hotkeys.json'
        content = JSON.stringify(keyBindings.hotkeys, null, 2)
        download_file filename, 'application/json', content
        view.showMessage "Downloaded hotkeys to #{filename}!", {text_class: 'success'}

    $("#hotkeys_default").click () =>
        do keyBindings.apply_default_hotkey_settings
        keyBindings.renderModeTable view.mode # TODO: do this elsewhere?
        view.showMessage "Loaded defaults!", {text_class: 'success'}

    $("#data_import").click () =>
        load_file $('#import-file :file')[0], (err, content, filename) ->
            if err then return view.showMessage err, {text_class: 'error'}
            mimetype = utils.mimetypeLookup filename
            if view.importContent content, mimetype
                view.showMessage 'Imported!', {text_class: 'success'}
                do view.hideSettings
            else
                view.showMessage 'Import failed due to parsing issue', {text_class: 'error'}

    $("#data_export").click () =>
        view.showMessage 'Exporting...'

        filename = (view.settings.getSetting 'export_filename') || 'vimflowy.json'
        # Infer mimetype from file extension
        mimetype = utils.mimetypeLookup filename
        content = view.exportContent mimetype
        download_file filename, mimetype, content
        view.showMessage "Exported to #{filename}!", {text_class: 'success'}

if chrome?.storage?.sync
  Logger.logger.info 'using chrome storage'

  # TODO
  # datastore = new dataStore.ChromeStorageLazy

  datastore = new dataStore.InMemory
  data = new Data datastore
  chrome.storage.sync.get 'save', (results) ->
    if results.save
      data.load results.save
    else
      data.load constants.default_data

    # save every 5 seconds
    setInterval (() ->
      chrome.storage.sync.set {
        'save': data.serialize()
      }, () ->
        # TODO have whether saved visualized
        Logger.logger.info 'Saved'
    ), 5000

    create_view data
else if localStorage?
  docname = window.location.pathname.split('/')[1]
  datastore = new dataStore.LocalStorageLazy docname
  data = new Data datastore

  if (do datastore.getLastSave) == 0
    data.load constants.default_data

  create_view data
else
  alert('You need local storage support for data to be persisted!')
  datastore = new dataStore.InMemory

  data = new Data datastore
  data.load constants.default_data

  create_view data

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
