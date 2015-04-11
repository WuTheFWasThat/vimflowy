keyCodeMap =
  27: 'esc'
  8: 'backspace'

class KeyHandler extends EventEmitter
  constructor: () ->
    super

  listen: () ->
    self = @
    $(document).keydown (e) ->
      console.log('keydown', e.keyCode)
      if e.keyCode of keyCodeMap
        key = keyCodeMap[e.keyCode]
      else
        key = do (String.fromCharCode e.keyCode).toLowerCase
        if e.shiftKey
          key = do key.toUpperCase

      if e.ctrlKey
        key = 'ctrl+' + key
      console.log('keycode', e.keyCode, key)
      self.emit 'keydown', key

