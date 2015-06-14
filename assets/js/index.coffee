# data structure:

# mapping from id to line

keybindingsDiv = $('#keybindings')

default_data = {
  line: ''
  children: ['']
}

if localStorage?
  showKeyBindings = true
  if localStorage.getItem('showKeyBindings') != null
    showKeyBindings = localStorage['showKeyBindings'] == 'true'
  if showKeyBindings
    keybindingsDiv.addClass 'active'

  datastore = new dataStore.LocalStorageLazy
  data = new Data datastore

  if localStorage.getItem('saved') == null
    data.load default_data
    localStorage['saved'] = 'true'

else
  alert('You need local storage support for data to be persisted!')
  datastore = new dataStore.InMemory

  data = new Data datastore
  data.load default_data

view = new View $('#view'), data

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
