# data structure:

# mapping from id to line
structure = [
  {
    id: 0
  }
]

data =
  # rootEl
  curEl: 0 # id
  cursor: 0
  0: []


mode = MODES.VISUAL

keyCodeMap =
  27: 'esc'

render = (onto, structure, data) ->
  for child in structure
    do onto.empty
    id = child.id
    elId = 'element-' + id
    el = $('<div>').attr 'id', elId
    elLine = $('<div>').attr 'id', (elId + '-line')

    console.log data, data[id]
    renderLine elLine, data[id]

    el.append elLine
    console.log 'elline', elLine
    console.log 'el', el
    console.log 'onto', onto
    onto.append el

renderLine = (onto, data) ->
  console.log data
  onto.text data.join ''

renderElement = (id) ->
  renderLine $('#element-' + id + '-line'), data[id]

$(document).ready ->

  render $('#contents'), structure, data

  $(document).keyup (e) ->
      key = keyCodeMap[e.keyCode]
      if key == 'esc'
          mode = MODES.VISUAL

  $(document).keypress (e) ->
     char = do (String.fromCharCode e.keyCode).toLowerCase
     shift = e.shiftKey

     console.log char
     if mode == MODES.VISUAL
         if char == 'a'
             mode = MODES.INSERT
         else if char == 'i'
             mode = MODES.INSERT
         else if char == 'u'
             # implement undo
             a = 'b'
     else if mode == MODES.INSERT
         writeChar = char
         if shift
             writeChar = do writeChar.toUpperCase
         console.log 'precur', JSON.stringify data[data.curEl]
         data[data.curEl].splice data.cursor, data.cursor, writeChar
         data.cursor += 1
         console.log 'cur', data[data.curEl]
         renderElement data.curEl

