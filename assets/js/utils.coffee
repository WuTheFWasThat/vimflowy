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


)(if typeof exports isnt 'undefined' then exports else window.utils = {})
