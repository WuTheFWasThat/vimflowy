_ = require 'lodash'
tv4 = require 'tv4'

# TODO: is quite silly to consider undefined as whitespace
exports.isWhitespace = (char) ->
  return (char == ' ') or (char == '\n') or (char == undefined)

# NOTE: currently unused
exports.isPunctuation = (char) ->
  return char == '.' or char == ',' or char == '!' or char == '?'

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

exports.tv4_validate = (data, schema, object="data") ->
    # 3rd argument: checks recursive
    # 4th argument: bans unknown properties
    if not tv4.validate(data, schema, true, true)
      throw new errors.GenericError(
        "Error validating #{object} schema #{JSON.stringify(data, null, 2)}: #{JSON.stringify(tv4.error)}"
      )

# shim for filling in default values, with tv4
exports.fill_tv4_defaults = (data, schema) ->
  for prop, prop_info of schema.properties
    if prop not of data
      if 'default' of prop_info
        def_val = prop_info['default']
        if typeof def_val != "function"
          def_val = _.cloneDeep def_val
        data[prop] = def_val
    # recursively fill in defaults for objects
    if prop_info.type == 'object'
      if prop not of data
        data[prop] = {}
      exports.fill_tv4_defaults data[prop], prop_info
