_ = require 'lodash'

Menu = require '../menu.coffee'
Modes = require '../modes.coffee'
keyDefinitions = require '../keyDefinitions.coffee'

MODES = Modes.modes

CMD_SEARCH = keyDefinitions.registerCommand {
  name: 'SEARCH'
  default_hotkeys:
    normal_like: ['/', 'ctrl+f']
}
keyDefinitions.registerAction [MODES.NORMAL], CMD_SEARCH, {
  description: 'Search',
}, () ->
  @session.setMode MODES.SEARCH
  @session.menu = new Menu @session.menuDiv, (chars) =>
    find = (document, query, options = {}) ->
      nresults = options.nresults or 10
      case_sensitive = options.case_sensitive

      results = [] # list of (path, index) pairs

      canonicalize = (x) ->
        return if options.case_sensitive then x else x.toLowerCase()

      get_words = (char_array) ->
        return (char_array.join '')
          .split(/\s/g)
          .filter((x) -> x.length)
          .map canonicalize

      query_words = get_words query
      if query.length == 0
        return results

      for path in document.orderedLines()
        line = canonicalize (document.getText path.row).join ''
        matches = []
        if _.every(query_words.map ((word) ->
          i = line.indexOf word
          if i == -1 then return false
          matches = matches.concat [i...i+word.length]
          return true
        ))
          results.push { path: path, matches: matches }
        if nresults > 0 and results.length == nresults
          break
      return results

    return _.map(
      (find @session.document, chars),
      (found) =>
        path = found.path
        highlights = {}
        for i in found.matches
          highlights[i] = true
        return {
          contents: @session.document.getLine path.row
          renderOptions: { highlights: highlights }
          fn: () =>
            @session.zoomInto path
            @session.cursor.setPath path
        }
    )

CMD_MENU_SELECT = keyDefinitions.registerCommand {
  name: 'MENU_SELECT'
  default_hotkeys:
    insert_like: ['enter']
}
keyDefinitions.registerAction [MODES.SEARCH], CMD_MENU_SELECT, {
  description: 'Select current menu selection',
}, () ->
  do @session.menu.select
  @session.setMode MODES.NORMAL

CMD_MENU_UP = keyDefinitions.registerCommand {
  name: 'MENU_UP'
  default_hotkeys:
    insert_like: ['ctrl+k', 'up', 'tab']
}
keyDefinitions.registerAction [MODES.SEARCH], CMD_MENU_UP, {
  description: 'Select previous menu selection',
}, () ->
  do @session.menu.up

CMD_MENU_DOWN = keyDefinitions.registerCommand {
  name: 'MENU_DOWN'
  default_hotkeys:
    insert_like: ['ctrl+j', 'down', 'shift+tab']
}
keyDefinitions.registerAction [MODES.SEARCH], CMD_MENU_DOWN, {
  description: 'Select next menu selection',
}, () ->
  do @session.menu.down
