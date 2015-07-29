class Clipboard
  WILDCARD = "*"
  DEFAULT_FORMAT: { store: "text/plain", load: [Clipboard.WILDCARD] }
  WILDCARD_ORDERING: ["text/plain", "Text", "application/json", "text/html"]
  store: (data, type) ->
    type ||= @DEFAULT_FORMAT.store
    if type == "text/plain" and isIe?
      type = "Text"
    clipboardData.setData(type, data)

  load: (typePreferences) ->
    typePreferences ||= [@DEFAULT_FORMAT.load]
    for type in typePreferences
      if type == Clipboard.WILDCARD
        return @load @WILDCARD_ORDERING # Return any available type
      else
        preferred = clipboardData.getData(type)
        if preferred?
          return [preferred, type]
    return undefined

  # Clipboard access only works in Chrome and IE, not Firefox or Safari
  available = () ->
    return clipboardData?

module?.exports = Clipboard
