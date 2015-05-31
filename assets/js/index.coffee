# data structure:

# mapping from id to line

keybindingsDiv = $('#keybindings')

serialized_data = {
  line: ''
  children: ['']
}

if localStorage?
  # localStorage['data'] = '{"line":"","children":["sdaasd"]}'
  if localStorage['data'] and localStorage['data'].length
    serialized_data = JSON.parse localStorage['data']

  showKeyBindings = true
  if localStorage.getItem('showKeyBindings') != null
    showKeyBindings = localStorage['showKeyBindings'] == 'true'
  if showKeyBindings
    keybindingsDiv.addClass 'active'

data = new Data (new InMemoryDataStore)
data.load serialized_data
console.log('loaded', serialized_data)

setInterval (() ->
  localStorage['data'] = JSON.stringify (do data.serialize)
), 1000


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
