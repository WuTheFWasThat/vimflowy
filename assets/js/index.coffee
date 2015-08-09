#= require settings
# data structure:

# mapping from id to line

view = null
create_view = (data) ->

  view = new View data, {
    bindings: KeyBindings
    mainDiv: $('#view'),
    settingsDiv: $('#settings')
    messageDiv: $('#message')
    keybindingsDiv: $('#keybindings')
    modeDiv: $('#mode')
    menuDiv: $('#menu')
  }

  $(window).on('paste', (e) ->
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
  keyhandler = new KeyHandler view, KeyBindings.bindings
  key_emitter.on 'keydown', keyhandler.handleKey.bind(keyhandler)

  $(document).ready ->
    do view.render

    $("#import_submit").click () =>
        file = $("#import-file :file")[0].files[0]
        if not file?
            view.showMessage 'Please select a file to import!'
            return
        view.showMessage 'Importing...'
        mimetype = utils.mimetypeLookup file.name
        reader = new FileReader()
        reader.readAsText file, "UTF-8"
        reader.onload = (evt) ->
            content = evt.target.result
            if view.importContent content, mimetype
                view.showMessage 'Imported!'
                window.location.hash = '' # close the modal
            else
                view.showMessage 'Import failed due to parsing issue'
        reader.onerror = (evt) ->
            view.showMessage 'Import failed due to file-reading issue'
            console.log 'Import Error', evt

    $("#export_submit").click () =>
        view.showMessage 'Exporting...'

        filename = (view.settings.getSetting 'export_filename') || 'vimflowy.json'
        # Infer mimetype from file extension
        mimetype = utils.mimetypeLookup filename
        content = view.exportContent mimetype

        $("#export").attr("download", filename)
        $("#export").attr("href", "data: #{mimetype};charset=utf-8,#{encodeURIComponent(content)}")
        $("#export")[0].click()
        $("#export").attr("download", null)
        $("#export").attr("href", null)

        view.showMessage 'Exported!'
        window.location.hash = '' # close the modal

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

  if (do datastore.lastSave) == 0
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
        Logger.logger.error 'Error: ', err, err.stack
    message = 'An error was caught.  Please refresh the page to avoid weird state. \n\n'
    message += 'Please help out vimflowy and report the bug.  If your data is not sensitive, '
    message += 'please open the javascript console and save the log as debug information.'
    alert message
