if module? # imports
  global._ = require('lodash')

((exports) ->

  exports.isWhitespace = (char) ->
    return (char == ' ') or (char == '\n') or (char == undefined)

  exports.mimetypeLookup = (filename) ->
    parts = filename.split '.'
    extension = if parts.length > 1 then parts[parts.length - 1] else ''
    extensionLookup =
      'json': 'application/json'
      'txt': 'text/plain'
      '': 'text/plain'
    return extensionLookup[extension.toLowerCase()]

  exports.isScrolledIntoView = (elem, container) ->
    $elem = $(elem)
    $container = $(container)

    docViewTop = $container.offset().top
    docViewBottom = docViewTop + $container.outerHeight()

    elemTop = $elem.offset().top
    elemBottom = elemTop + $elem.height()

    return ((elemBottom <= docViewBottom) && (elemTop >= docViewTop))

  exports.assert_arrays_equal = (arr_a, arr_b) ->
    a_minus_b = _.difference(arr_a, arr_b)
    if a_minus_b.length
      throw "Arrays not same, first contains: #{a_minus_b}"
    b_minus_a = _.difference(arr_b, arr_a)
    if b_minus_a.length
      throw "Arrays not same, second contains: #{b_minus_a}"

)(if typeof exports isnt 'undefined' then exports else window.utils = {})
