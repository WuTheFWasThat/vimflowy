_ = require 'lodash'

Plugins = require '../../assets/js/plugins.coffee'
Menu = require '../../assets/js/menu.coffee'
Modes = require '../../assets/js/modes.coffee'
DataStore = require '../../assets/js/datastore.coffee'
Document = (require '../../assets/js/document.coffee').Document
Session = require '../../assets/js/session.coffee'
View = require '../../assets/js/view.coffee'
mutations = require '../../assets/js/mutations.coffee'
errors = require '../../assets/js/errors.coffee'

basic_defs = require '../../assets/js/definitions/basics.coffee'

# NOTE: mark mode is still in the core code
# TODO: separate that out too?

class MarksPlugin
  constructor: (@api) ->
    do @enableAPI

  enableAPI: () ->
    @logger = @api.logger
    @session = @api.session
    @document = @session.document
    that = @

    class SetMark extends mutations.Mutation
      constructor: (@id, @mark) ->
      str: () ->
        return "row #{@id}, mark #{@mark}"
      mutate: (session) ->
        that._setMark @id, @mark
      rewind: (session) ->
        that._unsetMark @id, @mark
    @.SetMark = SetMark

    class UnsetMark extends mutations.Mutation
      constructor: (@id) ->
      str: () ->
        return "row #{@id}"
      mutate: (session) ->
        @mark = that._getMark @id
        that._unsetMark @id, @mark
      rewind: (session) ->
        that._setMark @id, @mark
    @.UnsetMark = UnsetMark

    # Serialization #

    @api.registerHook 'document', 'serializeRow', (struct, info) =>
      mark = @_getMark info.row.id
      if mark
        struct.mark = mark
      return struct

    @api.registerListener 'document', 'loadRow', (row, serialized) =>
      if serialized.mark
        err = @updateMark row.id, serialized.mark
        if err then @session.showMessage err, {text_class: 'error'}

    # Commands #

    MODES = Modes.modes

    @marksession = null
    @marksessionrow = null

    @api.registerMode {
      name: 'MARK'
      hotkey_type: Modes.INSERT_MODE_TYPE
      within_row: true
      enter: (session) =>
        # initialize marks stuff
        document = new Document (new DataStore.InMemory)
        @marksession = new Session document
        @marksessionrow = session.cursor.row
      exit: (session) =>
        @marksession = null
        @marksessionrow = null
      key_transforms: [
        (key, context) =>
          # must be non-whitespace
          if key.length == 1
            if /^\S*$/.test(key)
              @marksession.addCharsAtCursor [{char: key}], {cursor: {pastEnd: true}}
              return [null, context]
          return [key, context]
      ]
    }

    CMD_MARK = @api.registerCommand {
      name: 'MARK'
      default_hotkeys:
        normal_like: ['m']
    }
    @api.registerAction [MODES.NORMAL], CMD_MARK, {
      description: 'Mark a line',
    }, () ->
      @session.setMode MODES.MARK

    CMD_FINISH_MARK = @api.registerCommand {
      name: 'FINISH_MARK'
      default_hotkeys:
        insert_like: ['enter']
    }
    @api.registerAction [MODES.MARK], CMD_FINISH_MARK, {
      description: 'Finish typing mark',
    }, () ->
      mark = (do that.marksession.curText).join ''
      err = that.updateMark that.marksessionrow.id, mark
      if err then @session.showMessage err, {text_class: 'error'}
      @session.setMode MODES.NORMAL
      do @keyStream.save

    CMD_GO = @api.commands.GO
    @api.registerMotion [CMD_GO, CMD_MARK], {
      description: 'Go to the mark indicated by the cursor, if it exists',
    },  () ->
      return (cursor) =>
        word = @session.document.getWord cursor.row, cursor.col
        if word.length < 1 or word[0] != '@'
          return false
        mark = word[1..]
        allMarks = do that.listMarks
        if mark of allMarks
          id = allMarks[mark]
          row = @session.document.canonicalInstance id
          @session.zoomInto row
          return true
        else
          return false

    CMD_DELETE = @api.commands.DELETE
    @api.registerAction [MODES.NORMAL], [CMD_DELETE, CMD_MARK], {
      description: 'Delete mark at cursor'
    }, () ->
      err = (that.updateMark @session.cursor.row.id, '')
      if err then @session.showMessage err, {text_class: 'error'}
      do @keyStream.save

    CMD_MARK_SEARCH = @api.registerCommand {
      name: 'MARK_SEARCH'
      default_hotkeys:
        normal_like: ['\'', '`']
    }
    @api.registerAction [MODES.NORMAL], CMD_MARK_SEARCH, {
      description: 'Go to (search for) a mark',
    }, () ->
      @session.setMode MODES.SEARCH
      @session.menu = new Menu @session.menuDiv, (chars) =>
        # find marks that start with the prefix
        findMarks = (document, prefix, nresults = 10) =>
          results = [] # list of rows
          for mark, id of (do that.listMarks)
            if (mark.indexOf prefix) == 0
              row = @session.document.canonicalInstance id
              results.push { row: row, mark: mark }
              if nresults > 0 and results.length == nresults
                break
          return results

        text = chars.join('')
        return _.map(
          (findMarks @session.document, text),
          (found) =>
            row = found.row
            return {
              contents: @session.document.getLine row
              renderHook: (contents) ->
                contents.unshift virtualDom.h 'span', {
                  className: 'mark theme-bg-secondary theme-trim'
                }, found.mark
                return contents
              fn: () => @session.zoomInto row
            }
        )

    @api.registerAction [MODES.MARK], basic_defs.CMD_MOTION, {
      description: 'Move the cursor',
    }, (motion) =>
      motion that.marksession.cursor, {pastEnd: true}

    @api.registerAction [MODES.MARK], basic_defs.CMD_DELETE_LAST_CHAR, {
      description: 'Delete last character (i.e. backspace key)',
    }, () ->
      do that.marksession.deleteAtCursor

    @api.registerAction [MODES.MARK], basic_defs.CMD_DELETE_CHAR, {
      description: 'Delete character at the cursor (i.e. del key)',
    }, () ->
      @session.sarkvession.delCharsAfterCursor 1

    @api.registerAction [MODES.MARK], basic_defs.CMD_HELP, {
      description: 'Show/hide key bindings (edit in settings)',
    }, () ->
      do @session.toggleBindingsDiv
      @keyStream.forget 1

    @api.registerAction [MODES.MARK], basic_defs.CMD_EXIT_MODE, {
      description: 'Exit back to normal mode',
    }, () ->
      @session.setMode MODES.NORMAL
      do @keyStream.forget

    @api.registerHook 'session', 'renderCursorsDict', (cursors, info) =>
      marking = @marksessionrow? and @marksessionrow.is info.row
      if marking
        return {} # do not render any cursors on the regular line
      return cursors

    @api.registerHook 'session', 'renderLineContents', (lineContents, info) =>
      marking = @marksessionrow? and @marksessionrow.is info.row
      if marking
          markresults = View.virtualRenderLine @marksession, @marksession.cursor.row, {no_clicks: true}
          lineContents.unshift virtualDom.h 'span', {
            className: 'mark theme-bg-secondary theme-trim-accent'
          }, markresults
      else
          mark = @_getMark info.row.id
          if mark
            lineContents.unshift virtualDom.h 'span', {
              className: 'mark theme-bg-secondary theme-trim'
            }, mark
      return lineContents

    @api.registerHook 'session', 'renderLineWordHook', (line, word_info) =>
      if @session.mode == MODES.NORMAL
        if word_info.word[0] == '@'
          mark = word_info.word[1..]
          id = @getIdForMark mark
          if id != null
            markrow = @document.canonicalInstance id
            errors.assert (markrow != null)
            for i in [word_info.start..word_info.end]
              line[i].renderOptions.type = 'a'
              line[i].renderOptions.onclick = @goMark.bind @, markrow
      return line

  # maintain global marks data structures
  #   a map: id -> mark
  #   and a second map: mark -> id
  _getIdsToMarks: () ->
    @api.getData 'ids_to_marks', {}
  _setIdsToMarks: (ids_to_marks) ->
    @api.setData 'ids_to_marks', ids_to_marks
  _getMarksToIds: () ->
    @api.getData 'marks_to_ids', {}
  _setMarksToIds: (mark_to_ids) ->
    @api.setData 'marks_to_ids', mark_to_ids

  _sanityCheckMarks: () ->
    marks_to_ids = @_getMarksToIds()
    ids_to_marks = @_getIdsToMarks()
    marks_to_ids2 = {}
    for id, mark of ids_to_marks
      marks_to_ids2[mark] = parseInt id
    errors.assert_deep_equals marks_to_ids, marks_to_ids2, "Inconsistent ids_to_marks"

  # get mark for an id, '' if it doesn't exist
  _getMark: (id) ->
    marks = @_getIdsToMarks()
    return marks[id] or ''

  _setMark: (id, mark) ->
    do @_sanityCheckMarks
    marks_to_ids = @_getMarksToIds()
    ids_to_marks = @_getIdsToMarks()
    errors.assert not (mark in marks_to_ids)
    errors.assert not (id in ids_to_marks)
    marks_to_ids[mark] = id
    ids_to_marks[id] = mark
    @_setMarksToIds marks_to_ids
    @_setIdsToMarks ids_to_marks
    do @_sanityCheckMarks

  _unsetMark: (id, mark) ->
    do @_sanityCheckMarks
    marks_to_ids = @_getMarksToIds()
    ids_to_marks = @_getIdsToMarks()
    errors.assert_equals marks_to_ids[mark], id
    errors.assert_equals ids_to_marks[id], mark
    delete marks_to_ids[mark]
    delete ids_to_marks[id]
    @_setMarksToIds marks_to_ids
    @_setIdsToMarks ids_to_marks
    do @_sanityCheckMarks

  getIdForMark: (mark) ->
    do @_sanityCheckMarks
    marks_to_ids = @_getMarksToIds()
    if not (mark of marks_to_ids)
      return null
    id = marks_to_ids[mark]
    if @document.isAttached id
      return id
    return null

  listMarks: () ->
    do @_sanityCheckMarks
    marks_to_ids = @_getMarksToIds()

    all_marks = {}
    for mark,id of marks_to_ids
      if @document.isAttached id
        all_marks[mark] = id
    return all_marks

  # Set the mark for id
  # Returns whether setting mark succeeded
  updateMark: (id, mark = '') ->
    marks_to_ids = @_getMarksToIds()
    ids_to_marks = @_getIdsToMarks()
    oldmark = ids_to_marks[id]

    if not (oldmark or mark)
      return "No mark to delete!"

    if mark of marks_to_ids
      if marks_to_ids[mark] == id
        return "Already marked, nothing to do!"

      other_id = marks_to_ids[mark]
      if @document.isAttached other_id
        return "Mark '#{mark}' was already taken!"
      else
        @session.do new @UnsetMark other_id, mark

    if oldmark
      @session.do new @UnsetMark id, oldmark

    if mark
      @session.do new @SetMark id, mark

    return null

  goMark: (row) =>
    @session.zoomInto row
    do @session.save
    do @session.render

# NOTE: because listing marks filters, disabling is okay

pluginName = "Marks"

Plugins.register {
  name: pluginName
  author: "Jeff Wu"
  description:
    """
    Lets you tag a row with a string, and then reference that row with @markname.
    Fast search for marked rows, using '.
    """
}, ((api) ->
  new MarksPlugin api
), ((api) ->
  do api.deregisterAll
)
exports.pluginName = pluginName
