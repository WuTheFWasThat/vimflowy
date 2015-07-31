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
      # maybe put in insert mode?
      chars = text.split ''
      view.addCharsAtCursor chars
      do view.render
      do view.save
  )

  key_emitter = new KeyEmitter
  do key_emitter.listen
  keyhandler = new KeyHandler view, KeyBindings.bindings
  key_emitter.on 'keydown', keyhandler.handleKey.bind(keyhandler)

  $(document).ready ->
    do view.render

if chrome?.storage?.sync
  console.log('using chrome storage')

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
        console.log('saved')
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
    console.log("Caught error: '" + msg + "' from " + url + ":" + line)
    if err != undefined
        console.log 'Error: ', err, err.stack
    message = 'An error was caught.  Please refresh the page to avoid weird state. \n\n'
    message += 'Please help out vimflowy and report the bug.  If your data is not sensitive, '
    message += 'please open the javascript console and save the log as debug information.'
    alert message
