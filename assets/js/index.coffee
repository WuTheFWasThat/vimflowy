# data structure:

# mapping from id to line

data = new Data

if localStorage?
  # localStorage['data'] = '{"line":"","children":["sdaasd"]}'
  if localStorage['data'] and localStorage['data'].length
    data.load JSON.parse localStorage['data']

setInterval (() ->
  localStorage['data'] = JSON.stringify (do data.serialize)
), 1000


view = new View $('#contents'), data

$(window).on('paste', (e) ->
    e.preventDefault()
    text = (e.originalEvent || e).clipboardData.getData('text/plain')
    chars = text.split ''
    # TODO: deal with this better when there are multiple lines
    view.addCharsAfterCursor chars
)

keyhandler = new KeyHandler
do keyhandler.listen
keybinder = new KeyBindings $('#mode'), $('#keybindings'), view
keyhandler.on 'keydown', keybinder.handleKey.bind(keybinder)

$(document).ready ->
  do view.render
