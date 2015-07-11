#= require settings
# data structure:

# mapping from id to line

keybindingsDiv = $('#keybindings')

default_data = {
  line: ''
  children: ['']
  settings: Settings.default_settings
}

load_defaults = false

if chrome?.storage?.sync
  # TODO
  # console.log('using chrome storage')
  # datastore = new dataStore.ChromeStorageLazy
  datastore = new dataStore.InMemory
  data = new Data datastore
  load_defaults = true
else if localStorage?
  docname = window.location.pathname.split('/')[1]
  datastore = new dataStore.LocalStorageLazy docname
  data = new Data datastore

  if (do datastore.lastSave) == 0
    load_defaults = true
else
  alert('You need local storage support for data to be persisted!')
  datastore = new dataStore.InMemory

  data = new Data datastore
  load_defaults = true

if load_defaults
  data.load default_data
  datastore.setSetting 'showKeyBindings', true

if datastore.getSetting 'showKeyBindings'
  keybindingsDiv.addClass 'active'

view = new View $('#view'), data
settings = new Settings $('#settings'), data
do settings.loadRenderSettings

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
  do settings.bind
