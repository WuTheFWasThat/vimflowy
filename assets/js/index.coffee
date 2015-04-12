# data structure:

# mapping from id to line

data = new Data
view = new View $('#contents'), data

keyhandler = new KeyHandler
do keyhandler.listen
keybinder = new KeyBindings $('#mode'), $('#keybindings'), view
keyhandler.on 'keydown', keybinder.handleKey.bind(keybinder)

$(document).ready ->
  do view.render
