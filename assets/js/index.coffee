# data structure:

# mapping from id to line

data = new Data
view = new View $('#contents'), data

keyhandler = new KeyHandler
keybinder = new KeyBindings keyhandler, $('#mode'), $('#keybindings'), view

$(document).ready ->

  do view.render
  do keyhandler.listen
