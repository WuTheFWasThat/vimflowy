# data structure:

# mapping from id to line

keybindingsDiv = $('#keybindings')

default_data = {
  line: ''
  children: ['']
}

if localStorage?
  console.log('localstorage yay')
  showKeyBindings = true
  if localStorage.getItem('showKeyBindings') != null
    showKeyBindings = localStorage['showKeyBindings'] == 'true'
  if showKeyBindings
    keybindingsDiv.addClass 'active'

  datastore = new dataStore.LocalStorageLazy
  data = new Data datastore

  if localStorage.getItem('saved') == null
    console.log('no save')
    data.load default_data
    localStorage['saved'] = 'true'
  else
    console.log('saved before')

else
  alert('You need local storage support for data to be persisted')
  datastore = new dataStore.InMemory

  data = new Data datastore
  data.load default_data


view = new View $('#view'), data

$(window).on('paste', (e) ->
    e.preventDefault()
    text = (e.originalEvent || e).clipboardData.getData('text/plain')
    chars = text.split ''
    # TODO: deal with this better when there are multiple lines
    view.addCharsAtCursor chars
    do view.render
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
