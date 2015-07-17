#= require settings
# data structure:

# mapping from id to line

view = null
create_view = (data) ->
  keybindingsDiv = $('#keybindings')

  view = new View data, {
    mainDiv: $('#view'),
    settingsDiv: $('#settings')
    messageDiv: $('#message')
    keybindingsDiv: keybindingsDiv
  }

  $(window).on('paste', (e) ->
      e.preventDefault()
      text = (e.originalEvent || e).clipboardData.getData('text/plain')
      chars = text.split ''
      view.addCharsAtCursor chars
      # TODO: deal with this better when there are multiple lines
      # TODO: put in insert mode?
      do view.render
      do view.save
  )

  keyhandler = new KeyHandler
  do keyhandler.listen
  keybinder = new KeyBindings view, {
    modeDiv: $('#mode')
    keyBindingsDiv: keybindingsDiv
    menuDiv: $('#menu')
  }
  keyhandler.on 'keydown', keybinder.handleKey.bind(keybinder)

  $(document).ready ->
    do view.render

load_defaults = (data) ->
  default_data = {
    line: ''
    children: ['']
  }
  data.load default_data

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
      load_defaults data

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
    load_defaults data

  create_view data
else
  alert('You need local storage support for data to be persisted!')
  datastore = new dataStore.InMemory

  data = new Data datastore
  load_defaults data

  create_view data

