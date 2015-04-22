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

keyhandler = new KeyHandler
do keyhandler.listen
keybinder = new KeyBindings $('#mode'), $('#keybindings'), view
keyhandler.on 'keydown', keybinder.handleKey.bind(keybinder)

$(document).ready ->
  do view.render
