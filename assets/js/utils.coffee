((exports) ->

  exports.isWhitespace = (char) ->
    return (char == ' ') or (char == '\n') or (char == undefined)

)(if typeof exports isnt 'undefined' then exports else window.utils = {})
