if module?
  global._ = require('lodash')
  global.errors = require('./errors.coffee')
  global.Logger = require('./logger.coffee')

###
DataStore abstracts the data layer, so that it can be swapped out.
There are many methods the each type of DataStore should implement to satisfy the API.
However, in the case of a key-value store, one can simply implement `get` and `set` methods.
Currently, DataStore has a synchronous API.  This may need to change eventually...  :(
###
((exports) ->
  class DataStore
    constructor: (prefix='') ->
      @_schemaVersion_ = 1

      @prefix = "#{prefix}save"

      @_lineKey_ = (row) -> "#{@prefix}:#{row}:line"
      @_parentKey_ = (row) -> "#{@prefix}:#{row}:parent"
      @_childrenKey_ = (row) -> "#{@prefix}:#{row}:children"
      @_collapsedKey_ = (row) -> "#{@prefix}:#{row}:collapsed"

      # no prefix, meaning it's global
      @_settingKey_ = (setting) -> "settings:#{setting}"

      @_lastSaveKey_ = "#{@prefix}:lastSave"
      @_lastViewrootKey_ = "#{@prefix}:lastviewroot2"
      @_allMarksKey_ = "#{@prefix}:allMarks"
      @_IDKey_ = "#{@prefix}:lastID"
      @_schemaVersionKey_ = "#{@prefix}:schemaVersion"
      do @validateSchemaVersion

    get: (key, default_value=null) ->
        throw new errors.NotImplemented

    set: (key, value) ->
        throw new errors.NotImplemented

    # get and set values for a given row
    getLine: (row) ->
      _.cloneDeep (@get (@_lineKey_ row), [])
    setLine: (row, line) ->
      @set (@_lineKey_ row), line

    getParents: (row) ->
      parents = @get (@_parentKey_ row), []
      if typeof parents == 'number'
        parents = [ parents ]
      parents
    setParents: (row, parents) ->
      @set (@_parentKey_ row), parents

    getChildren: (row) ->
      _.cloneDeep (@get (@_childrenKey_ row), [])
    setChildren: (row, children) ->
      @set (@_childrenKey_ row), children

    getCollapsed: (row) ->
      @get (@_collapsedKey_ row)
    setCollapsed: (row, collapsed) ->
      @set (@_collapsedKey_ row), collapsed

    # get global settings (data not specific to a document)
    getSetting: (setting) ->
      @get (@_settingKey_ setting)
    setSetting: (setting, value) ->
      @set (@_settingKey_ setting), value

    # maintain global marks datastructure.  maps mark -> row
    getAllMarks: () ->
      @get @_allMarksKey_, {}
    setAllMarks: (marks) ->
      @set @_allMarksKey_, marks

    # get last view (for page reload)
    setLastViewRoot: (ancestry) ->
      @set @_lastViewrootKey_, ancestry
    getLastViewRoot: () ->
      @get @_lastViewrootKey_, []

    setSchemaVersion: (version) ->
      @set @_schemaVersionKey_, version
    getSchemaVersion: () ->
      @get @_schemaVersionKey_, 1

    # get next row ID
    getId: () -> # Suggest to override this for efficiency
      id = 0
      while (@get (@_lineKey_ id), null) != null
        id++
      id

    getNew: () ->
      id = do @getId
      @setLine id, []
      @setChildren id, []
      return id

    validateSchemaVersion: () ->
      storedVersion = do @getSchemaVersion
      if not storedVersion? and (@getChildren 0).length == 0
        @setSchemaVersion @_schemaVersion_
        return
      else if storedVersion > @_schemaVersion_
        throw new errors.SchemaVersion "The stored data was made with a newer version of vimflowy. Please upgrade vimflowy to use this format."
      else if storedVersion < @_schemaVersion_
        throw new errors.SchemaVersion "The stored data was made with an older version of vimflowy, and no migration paths exist. Please report this as a bug."
      else if storedVersion == @_schemaVersion_
        return

  class InMemory extends DataStore
    constructor: () ->
      @cache = {}
      super ''

    get: (key, default_value = null) ->
      if key of @cache
        @cache[key]
      else
        default_value

    set: (key, value) ->
      @cache[key] = value

  class LocalStorageLazy extends DataStore
    constructor: (prefix='') ->
      @cache = {}
      super prefix
      @lastSave = do Date.now

    get: (key, default_value=null) ->
      if not (key of @cache)
        @cache[key] = @_getLocalStorage_ key, default_value
      return @cache[key]

    set: (key, value) ->
      @cache[key] = value
      @_setLocalStorage_ key, value

    _setLocalStorage_: (key, value, options={}) ->
      if (do @getLastSave) > @lastSave
        alert '
          This document has been modified (in another tab) since opening it in this tab.
          Please refresh to continue!
        '
        throw new errors.DataPoisoned 'Last save disagrees with cache'

      unless options.doesNotAffectLastSave
        @lastSave = Date.now()
        localStorage.setItem @_lastSaveKey_, @lastSave

      Logger.logger.debug 'setting local storage', key, value
      localStorage.setItem key, JSON.stringify value

    _getLocalStorage_: (key, default_value) ->
      Logger.logger.debug 'getting from local storage', key, default_value
      stored = localStorage.getItem key
      if stored == null
        Logger.logger.debug 'got nothing, defaulting to', default_value
        return default_value
      try
        val = JSON.parse stored
        Logger.logger.debug 'got ', val
        return val
      catch
        Logger.logger.debug 'parse failure:', stored
        return default_value

    # determine last time saved (for multiple tab detection)
    # doesn't cache!
    getLastSave: () ->
      @_getLocalStorage_ @_lastSaveKey_, 0

    setSchemaVersion: (version) ->
      @_setLocalStorage_ @_schemaVersionKey_, version, { doesNotAffectLastSave: true }

    getId: () ->
      id = @_getLocalStorage_ @_IDKey_, 0
      while (@_getLocalStorage_ (@_lineKey_ id), null) != null
        id++
      @_setLocalStorage_ @_IDKey_, (id + 1)
      return id

  exports.InMemory = InMemory
  exports.LocalStorageLazy = LocalStorageLazy
  # TODO: exports.ChromeStorageLazy = ChromeStorageLazy
)(if typeof exports isnt 'undefined' then exports else window.dataStore = {})
