if module?
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

  # shim for filling in default values, with tv4
  exports.fill_tv4_defaults = (data, schema) ->
    for prop, prop_info of schema.properties
      if prop not of data
        if 'default' of prop_info
          data[prop] = _.cloneDeep prop_info['default']

)(if typeof exports isnt 'undefined' then exports else window.utils = {})
