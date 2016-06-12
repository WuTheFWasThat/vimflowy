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
      constructor: (@row, @mark) ->
      str: () ->
        return "row #{@row}, mark #{@mark}"
      mutate: (session) ->
        that._setMark @row, @mark
      rewind: (session) ->
        that._unsetMark @row, @mark
    @.SetMark = SetMark

    class UnsetMark extends mutations.Mutation
      constructor: (@row) ->
      str: () ->
        return "row #{@row}"
      mutate: (session) ->
        @mark = that._getMark @row
        that._unsetMark @row, @mark
      rewind: (session) ->
        that._setMark @row, @mark
    @.UnsetMark = UnsetMark

    # Serialization #

    @api.registerHook 'document', 'serializeRow', (struct, info) =>
      mark = @_getMark info.row
      if mark
        struct.mark = mark
      return struct

    @api.registerListener 'document', 'loadRow', (path, serialized) =>
      if serialized.mark
        err = @updateMark path.row, serialized.mark
        if err then @session.showMessage err, {text_class: 'error'}

    # Commands #

    MODES = Modes.modes

    @marksession = null
    @marksessionpath = null

    @api.registerMode {
      name: 'MARK'
      hotkey_type: Modes.INSERT_MODE_TYPE
      within_row: true
      enter: (session) =>
        # initialize marks stuff
        document = new Document (new DataStore.InMemory)
        @marksession = new Session document
        @marksession.setMode MODES.INSERT
        @marksessionpath = session.cursor.path
      exit: (session) =>
        @marksession = null
        @marksessionpath = null
      key_transforms: [
        (key, context) =>
          # must be non-whitespace
          if key.length == 1
            if /^\S*$/.test(key)
              @marksession.addCharsAtCursor [{char: key}]
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
      err = that.updateMark that.marksessionpath.row, mark
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
          row = allMarks[mark]
          path = @session.document.canonicalPath row
          @session.zoomInto path
          return true
        else
          return false

    CMD_DELETE = @api.commands.DELETE
    @api.registerAction [MODES.NORMAL], [CMD_DELETE, CMD_MARK], {
      description: 'Delete mark at cursor'
    }, () ->
      err = (that.updateMark @session.cursor.row, '')
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
          results = [] # list of paths
          for mark, row of (do that.listMarks)
            if (mark.indexOf prefix) == 0
              path = @session.document.canonicalPath row
              results.push { path: path, mark: mark }
              if nresults > 0 and results.length == nresults
                break
          return results

        text = chars.join('')
        return _.map(
          (findMarks @session.document, text),
          (found) =>
            path = found.path
            return {
              contents: @session.document.getLine path.row
              renderHook: (contents) ->
                contents.unshift virtualDom.h 'span', {
                  className: 'mark theme-bg-secondary theme-trim'
                }, found.mark
                return contents
              fn: () => @session.zoomInto path
            }
        )

    @api.registerAction [MODES.MARK], basic_defs.CMD_MOTION, {
      description: 'Move the cursor',
    }, (motion) ->
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
      marking = @marksessionpath? and @marksessionpath.is info.path
      if marking
        return {} # do not render any cursors on the regular line
      return cursors

    @api.registerHook 'session', 'renderLineContents', (lineContents, info) =>
      marking = @marksessionpath? and @marksessionpath.is info.path
      if marking
        markresults = View.virtualRenderLine @marksession, @marksession.cursor.path, {no_clicks: true}
        lineContents.unshift virtualDom.h 'span', {
          className: 'mark theme-bg-secondary theme-trim-accent'
        }, markresults
      else
        mark = @_getMark info.path.row
        if mark
          lineContents.unshift virtualDom.h 'span', {
            className: 'mark theme-bg-secondary theme-trim'
          }, mark
      return lineContents

    @api.registerHook 'session', 'renderLineWordHook', (line, word_info) =>
      if @session.mode == MODES.NORMAL
        if word_info.word[0] == '@'
          mark = word_info.word[1..]
          row = @getRowForMark mark
          if row != null
            markpath = @document.canonicalPath row
            errors.assert (markpath != null)
            for i in [word_info.start..word_info.end]
              line[i].renderOptions.type = 'a'
              line[i].renderOptions.onclick = @goMark.bind @, markpath
      return line

  # maintain global marks data structures
  #   a map: row -> mark
  #   and a second map: mark -> row
  _getRowsToMarks: () ->
    @api.getData 'ids_to_marks', {}
  _setRowsToMarks: (rows_to_marks) ->
    @api.setData 'ids_to_marks', rows_to_marks
  _getMarksToRows: () ->
    @api.getData 'marks_to_ids', {}
  _setMarksToRows: (mark_to_rows) ->
    @api.setData 'marks_to_ids', mark_to_rows

  _sanityCheckMarks: () ->
    marks_to_rows = @_getMarksToRows()
    rows_to_marks = @_getRowsToMarks()
    marks_to_rows2 = {}
    for row, mark of rows_to_marks
      marks_to_rows2[mark] = parseInt row
    errors.assert_deep_equals marks_to_rows, marks_to_rows2, "Inconsistent rows_to_marks"

  # get mark for an row, '' if it doesn't exist
  _getMark: (row) ->
    marks = @_getRowsToMarks()
    return marks[row] or ''

  _setMark: (row, mark) ->
    do @_sanityCheckMarks
    marks_to_rows = @_getMarksToRows()
    rows_to_marks = @_getRowsToMarks()
    errors.assert not (mark in marks_to_rows)
    errors.assert not (row in rows_to_marks)
    marks_to_rows[mark] = row
    rows_to_marks[row] = mark
    @_setMarksToRows marks_to_rows
    @_setRowsToMarks rows_to_marks
    do @_sanityCheckMarks

  _unsetMark: (row, mark) ->
    do @_sanityCheckMarks
    marks_to_rows = @_getMarksToRows()
    rows_to_marks = @_getRowsToMarks()
    errors.assert_equals marks_to_rows[mark], row
    errors.assert_equals rows_to_marks[row], mark
    delete marks_to_rows[mark]
    delete rows_to_marks[row]
    @_setMarksToRows marks_to_rows
    @_setRowsToMarks rows_to_marks
    do @_sanityCheckMarks

  getRowForMark: (mark) ->
    do @_sanityCheckMarks
    marks_to_rows = @_getMarksToRows()
    if not (mark of marks_to_rows)
      return null
    row = marks_to_rows[mark]
    if @document.isAttached row
      return row
    return null

  listMarks: () ->
    do @_sanityCheckMarks
    marks_to_rows = @_getMarksToRows()

    all_marks = {}
    for mark, row of marks_to_rows
      if @document.isAttached row
        all_marks[mark] = row
    return all_marks

  # Set the mark for row
  # Returns whether setting mark succeeded
  updateMark: (row, mark = '') ->
    marks_to_rows = @_getMarksToRows()
    rows_to_marks = @_getRowsToMarks()
    oldmark = rows_to_marks[row]

    if not (oldmark or mark)
      return "No mark to delete!"

    if mark of marks_to_rows
      if marks_to_rows[mark] == row
        return "Already marked, nothing to do!"

      other_row = marks_to_rows[mark]
      if @document.isAttached other_row
        return "Mark '#{mark}' was already taken!"
      else
        @session.do new @UnsetMark other_row, mark

    if oldmark
      @session.do new @UnsetMark row, oldmark

    if mark
      @session.do new @SetMark row, mark

    return null

  goMark: (path) =>
    @session.zoomInto path
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
