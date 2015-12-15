if module?
  global.Plugins = require('../../assets/js/plugins.coffee')
  global.TestCase = require('../../test/testcase.coffee')

(() ->
  # NOTE: mark mode is still in the core code
  # TODO: separate that out too?

  enableMarks = (api) ->

    view = api.view
    data = view.data

    # maintain global marks datastructures
    #   a map: id -> mark
    #   and a second map: mark -> id
    _getIdsToMarks = () ->
      api.getData 'ids_to_marks', {}
    _setIdsToMarks = (ids_to_marks) ->
      api.setData 'ids_to_marks', ids_to_marks
    _getMarksToIds = () ->
      api.getData 'marks_to_ids', {}
    _setMarksToIds = (mark_to_ids) ->
      api.setData 'marks_to_ids', mark_to_ids

    # get mark for an id, '' if it doesn't exist
    _getMark = (id) ->
      marks = _getIdsToMarks()
      return marks[id] or ''

    _setMark = (id, mark) ->
      marks_to_ids = _getMarksToIds()
      ids_to_marks = _getIdsToMarks()
      api.errors.assert not (mark in marks_to_ids)
      api.errors.assert not (id in ids_to_marks)
      marks_to_ids[mark] = id
      ids_to_marks[id] = mark
      _setMarksToIds marks_to_ids
      _setIdsToMarks ids_to_marks

    _unsetMark = (id, mark) ->
      marks_to_ids = _getMarksToIds()
      ids_to_marks = _getIdsToMarks()
      api.errors.assert_equals marks_to_ids[mark], id
      api.errors.assert_equals ids_to_marks[id], mark
      delete marks_to_ids[mark]
      delete ids_to_marks[id]
      _setMarksToIds marks_to_ids
      _setIdsToMarks ids_to_marks

    getIdForMark = (mark) ->
      marks_to_ids = _getMarksToIds()
      if not (mark of marks_to_ids)
        return null
      id = marks_to_ids[mark]
      if data.isAttached id
        return id
      return null

    listMarks = () ->
      marks_to_ids = _getMarksToIds()

      # sanity check
      ids_to_marks = _getIdsToMarks()
      marks_to_ids2 = {}
      for id, mark of ids_to_marks
        marks_to_ids2[mark] = parseInt id
      api.errors.assert_deep_equals marks_to_ids, marks_to_ids2, "Inconsistent ids_to_marks"

      all_marks = {}
      for mark,id of marks_to_ids
        if data.isAttached id
          all_marks[mark] = id
      return all_marks

    class SetMark extends api.Mutation
      constructor: (@id, @mark) ->
      str: () ->
        return "row #{@id}, mark #{@mark}"
      mutate: (view) ->
        _setMark @id, @mark
      rewind: (view) ->
        _unsetMark @id, @mark
    window?.SetMark = SetMark

    class UnsetMark extends api.Mutation
      constructor: (@id) ->
      str: () ->
        return "row #{@id}"
      mutate: (view) ->
        @mark = _getMark @id
        _unsetMark @id, @mark
      rewind: (view) ->
        _setMark @id, @mark
    window?.UnsetMark = UnsetMark

    # Set the mark for id
    # Returns whether setting mark succeeded
    updateMark = (id, mark = '') ->
      marks_to_ids = _getMarksToIds()
      ids_to_marks = _getIdsToMarks()
      oldmark = ids_to_marks[id]

      if not (oldmark or mark)
        return "No mark to delete!"

      if mark of marks_to_ids
        if marks_to_ids[mark] == id
          return "Already marked, nothing to do!"

        other_id = marks_to_ids[mark]
        if data.isAttached other_id
          return "Mark '#{mark}' was already taken!"
        else
          view.do new UnsetMark other_id, mark

      if oldmark
        view.do new UnsetMark id, oldmark

      if mark
        view.do new SetMark id, mark

      return null

    # Serialization #

    data.addHook 'serializeRow', (struct, info) ->
      mark = _getMark info.row.id
      if mark
        struct.mark = mark
      return struct

    data.on 'loadRow', (row, serialized) ->
      if serialized.mark
        err = updateMark row.id, serialized.mark
        if err then view.showMessage err, {text_class: 'error'}

    # Testing #
    if TestCase?
      TestCase.prototype.expectMarks = (expected) ->
        @_expectDeepEqual expected, (do listMarks), "Wrong marks"
        return @

    # Commands #

    MODES = api.modes

    CMD_MARK = api.registerCommand {
      name: 'MARK'
      default_hotkeys:
        normal_like: ['m']
    }
    api.registerAction [MODES.NORMAL], CMD_MARK, {
      description: 'Mark a line',
    }, () ->
      @view.setMode MODES.MARK

    CMD_FINISH_MARK = api.registerCommand {
      name: 'FINISH_MARK'
      default_hotkeys:
        insert_like: ['enter']
    }
    api.registerAction [MODES.MARK], CMD_FINISH_MARK, {
      description: 'Finish typing mark',
    }, () ->
      mark = (do @view.markview.curText).join ''
      err = updateMark @view.markrow.id, mark
      if err then @view.showMessage err, {text_class: 'error'}
      @view.setMode MODES.NORMAL
      do @keyStream.save

    CMD_GO = api.commands.GO
    api.registerMotion [CMD_GO, CMD_MARK], {
      description: 'Go to the mark indicated by the cursor, if it exists',
    },  () ->
      return (cursor) =>
        word = @view.data.getWord cursor.row, cursor.col
        if word.length < 1 or word[0] != '@'
          return false
        mark = word[1..]
        allMarks = do listMarks
        if mark of allMarks
          id = allMarks[mark]
          row = @view.data.canonicalInstance id
          @view.rootToParent row
          return true
        else
          return false

    CMD_DELETE = api.commands.DELETE
    api.registerAction [MODES.NORMAL], [CMD_DELETE, CMD_MARK], {
      description: 'Delete mark at cursor'
    }, () ->
      err = (updateMark @view.cursor.row.id, '')
      if err then @view.showMessage err, {text_class: 'error'}
      do @keyStream.save

    CMD_MARK_SEARCH = api.registerCommand {
      name: 'MARK_SEARCH'
      default_hotkeys:
        normal_like: ['\'', '`']
    }
    api.registerAction [MODES.NORMAL], CMD_MARK_SEARCH, {
      description: 'Go to (search for) a mark',
    }, () ->
      @view.setMode MODES.SEARCH
      @view.menu = new Menu @view.menuDiv, (chars) =>
        # find marks that start with the prefix
        findMarks = (data, prefix, nresults = 10) =>
          results = [] # list of rows
          for mark, id of (do listMarks)
            if (mark.indexOf prefix) == 0
              row = @view.data.canonicalInstance id
              results.push { row: row, mark: mark }
              if nresults > 0 and results.length == nresults
                break
          return results

        text = chars.join('')
        return _.map(
          (findMarks @view.data, text),
          (found) =>
            row = found.row
            return {
              contents: @view.data.getLine row
              renderHook: (contents) ->
                contents.unshift virtualDom.h 'span', {
                  className: 'mark theme-bg-secondary theme-trim'
                }, found.mark
                return contents
              fn: () => @view.rootInto row
            }
        )

    view.addHook 'renderCursorsDict', (cursors, info) ->
      marking = view.markrow? and view.markrow.is info.row
      if marking
        return {} # do not render any cursors on the regular line
      return cursors

    view.addHook 'renderLineContents', (lineContents, info) ->
      marking = view.markrow? and view.markrow.is info.row

      if marking
          markresults = view.markview.virtualRenderLine view.markview.cursor.row, {no_clicks: true}
          lineContents.unshift virtualDom.h 'span', {
            className: 'mark theme-bg-secondary theme-trim-accent'
          }, markresults
      else
          mark = _getMark info.row.id
          if mark
            lineContents.unshift virtualDom.h 'span', {
              className: 'mark theme-bg-secondary theme-trim'
            }, mark
      return lineContents

    view.addHook 'renderLineTextOptions', (line, info) ->
      if view.mode == MODES.NORMAL
        goMark = (row) =>
          view.rootToParent row
          do view.save
          do view.render

        # gather words that are marks
        for word in info.words
          if word.word[0] == '@'
            mark = word.word[1..]
            id = getIdForMark mark
            if id != null
              markrow = data.canonicalInstance id
              errors.assert (markrow != null)
              for i in [word.start..word.end]
                line[i].renderOptions.type = 'a'
                line[i].renderOptions.classes.push 'theme-text-link'
                line[i].renderOptions.onclick = goMark.bind @, markrow
      return line

  Plugins.register {
    name: "Marks"
    author: "Jeff Wu"
    description:
      """
      Lets you tag a row with a string, and then reference that row with an @<mark>.
      Fast search for marked rows.
      """
  }, enableMarks
  # NOTE: because listing marks filters, disabling is okay
)()
