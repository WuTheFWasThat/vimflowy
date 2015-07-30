if module?
  _ = require('underscore')

((exports) ->
  class DataStore
    constructor: () ->
      return

    # get and set values for a given row
    getLine: (row) ->
      throw 'Not implemented'
    setLine: (row, line) ->
      throw 'Not implemented'
    getParent: (row) ->
      throw 'Not implemented'
    setParent: (row, parent) ->
      throw 'Not implemented'
    getChildren: (row) ->
      throw 'Not implemented'
    setChildren: (row, children) ->
      throw 'Not implemented'
    getMark: (row) ->
      throw 'Not implemented'
    setMark: (row, marks) ->
      throw 'Not implemented'
    getCollapsed: (row) ->
      throw 'Not implemented'
    setCollapsed: (row, collapsed) ->
      throw 'Not implemented'

    # get global settings
    getSetting: (setting) ->
      throw 'Not implemented'
    setSetting: (setting, value) ->
      throw 'Not implemented'

    # maintain global marks datastructure
    getAllMarks: () ->
      throw 'Not implemented'
    setAllMarks: (marks) ->
      throw 'Not implemented'

    # get next row ID
    getId: () ->
      throw 'Not implemented'
    getNew: () ->
      id = do @getId
      @setLine id, []
      @setChildren id, []
      return id

    # get last view (for page reload)
    setLastViewRoot: (row) ->
      throw 'Not implemented'
    getLastViewRoot: () ->
      throw 'Not implemented'

    # delete: (id) ->
    #  throw 'Not implemented'

  class InMemory extends DataStore
    constructor: () ->
      @lines = {}
      @parents = {}
      @children = {}
      @collapsed = {}
      @marks = {}

      @settings = {}
      @allMarks = {}
      return

    getLine: (row) ->
      return [].slice.apply @lines[row]

    setLine: (row, line) ->
      @lines[row] = line

    getParent: (row) ->
      return @parents[row]

    setParent: (row, parent) ->
      @parents[row] = parent

    getChildren: (row) ->
      return [].slice.apply @children[row]

    setChildren: (row, children) ->
      @children[row] = children

    getCollapsed: (row) ->
      return @collapsed[row]

    setCollapsed: (row, collapsed) ->
      @collapsed[row] = collapsed

    getMark: (row) ->
      return @marks[row]

    setMark: (row, mark) ->
      @marks[row] = mark

    getSetting: (setting) ->
      return @settings[setting]

    setSetting: (setting, value) ->
      @settings[setting] = value

    setLastViewRoot: (row) ->
      return # no point in remembering

    getLastViewRoot: () ->
      return 0

    getAllMarks: () ->
      return _.clone @allMarks

    setAllMarks: (marks) ->
      @allMarks = marks

    getId: () ->
      id = 0
      while @lines[id]
        id++
      return id

    # delete: (id) ->
    #   delete @children[id]
    #   delete @parents[id]
    #   delete @lines[id]
    #   delete @collapsed[id]

  class LocalStorageLazy extends DataStore
    constructor: (prefix='') ->
      @prefix = "#{prefix}save"

      @_lineKey_ = (row) ->
        return "#{@prefix}:#{row}:line"

      @_parentKey_ = (row) ->
        return "#{@prefix}:#{row}:parent"

      @_childrenKey_ = (row) ->
        return "#{@prefix}:#{row}:children"

      @_collapsedKey_ = (row) ->
        return "#{@prefix}:#{row}:collapsed"

      @_markKey_ = (row) ->
        return "#{@prefix}:#{row}:mark"

      # no prefix, meaning it's global
      @_settingKey_ = (setting) ->
        return "settings:#{setting}"

      @_lastSaveKey_ = "#{@prefix}:lastSave"
      @_lastViewrootKey_ = "#{@prefix}:lastviewroot"
      @_allMarksKey_ = "#{@prefix}:marks"
      @_IDKey_ = "#{@prefix}:lastID"

      @lines = {}
      @parents = {}
      @children = {}
      @collapsed = {}
      @marks = {}
      @settings = {}
      @allMarks = @_getLocalStorage_ @_allMarksKey_, {}
      return

    _setLocalStorage_: (key, value) ->
      console.log('setting local storage', key, value)
      localStorage.setItem key, JSON.stringify value
      localStorage.setItem @_lastSaveKey_, (do Date.now)

    _getLocalStorage_: (key, default_value = null) ->
      console.log('getting from local storage', key, default_value)
      stored = localStorage.getItem key
      if stored == null
        console.log('got nothing, defaulting')
        return default_value
      try
        val = JSON.parse stored
        console.log('got val', val)
        return val
      catch
        console.log('parse failure??', stored)
        return default_value

    lastSave: () ->
      return @_getLocalStorage_ @_lastSaveKey_, 0

    getLine: (row) ->
      if not (row of @lines)
        @lines[row] = @_getLocalStorage_ @_lineKey_ row
      return [].slice.apply @lines[row]

    setLine: (row, line) ->
      @lines[row] = line
      @_setLocalStorage_ (@_lineKey_ row), line

    getParent: (row) ->
      if not (row of @parents)
        @parents[row] = @_getLocalStorage_ @_parentKey_ row
      return @parents[row]

    setParent: (row, parent) ->
      @parents[row] = parent
      @_setLocalStorage_ (@_parentKey_ row), parent

    getChildren: (row) ->
      if not (row of @children)
        @children[row] = @_getLocalStorage_ @_childrenKey_ row
      return [].slice.apply @children[row]

    setChildren: (row, children) ->
      @children[row] = children
      @_setLocalStorage_ (@_childrenKey_ row), children

    getCollapsed: (row) ->
      if not (row of @collapsed)
        @collapsed[row] = @_getLocalStorage_ @_collapsedKey_ row
      return @collapsed[row]

    setCollapsed: (row, collapsed) ->
      @collapsed[row] = collapsed
      @_setLocalStorage_ (@_collapsedKey_ row), collapsed

    getMark: (row) ->
      if not (row of @marks)
        @marks[row] = @_getLocalStorage_ @_markKey_ row, ''
      return @marks[row]

    setMark: (row, mark) ->
      @marks[row] = mark
      @_setLocalStorage_ (@_markKey_ row), mark

    getSetting: (setting) ->
      if not (setting of @settings)
        @settings[setting] = @_getLocalStorage_ @_settingKey_ setting
      return @settings[setting]

    setSetting: (setting, value) ->
      @settings[setting] = value
      @_setLocalStorage_ (@_settingKey_ setting), value

    setLastViewRoot: (row) ->
      @_setLocalStorage_ @_lastViewrootKey_ , row

    getAllMarks: () ->
      return _.clone @allMarks

    setAllMarks: (marks) ->
      @allMarks = _.clone marks
      return @_setLocalStorage_ @_allMarksKey_, marks

    getLastViewRoot: () ->
      id = @_getLocalStorage_ @_lastViewrootKey_ , 0
      if (localStorage.getItem @_lineKey_ id) == null
        console.log 'GOT INVALID VIEW ROOT', id
        id = 0
      return id

    getId: () ->
      id = @_getLocalStorage_ @_IDKey_, 0
      while (localStorage.getItem @_lineKey_ id) != null
        id++
      @_setLocalStorage_ @_IDKey_, (id + 1)
      return id

    # delete: (id) ->
    #   delete @structure[id]
    #   delete @lines[id]

  exports.InMemory = InMemory
  exports.LocalStorageLazy = LocalStorageLazy
  # TODO: exports.ChromeStorageLazy = ChromeStorageLazy
)(if typeof exports isnt 'undefined' then exports else window.dataStore = {})
