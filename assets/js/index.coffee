# data structure:

# mapping from id to line

keyCodeMap =
  27: 'esc'

data = new Data
view = new View $('#contents'), $('#mode'), data

$(document).ready ->

  do view.render

  $(document).keydown (e) ->
    console.log('keydown', e.keyCode)
    if e.keyCode of keyCodeMap
      key = keyCodeMap[e.keyCode]
    else
      key = do (String.fromCharCode e.keyCode).toLowerCase
      if e.shiftKey
        key = do key.toUpperCase

    options =
      ctrl: e.ctrlKey
    console.log('keycode', e.keyCode, key, options)
    view.handleKey key, options

