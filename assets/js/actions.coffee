if module?
  global.errors = require('./errors.coffee')

((exports) ->

  # actions mutate the data of a view, and are undoable

  class Action
    str: () ->
      return ''
    apply: (view) ->
      return
    rewind: (view) ->
      return
    reapply: (view) ->
      return @apply view

  class AddChars extends Action
    # options:
    #   setCursor: if you wish to set the cursor, set to 'beginning' or 'end'
    #              indicating where the cursor should go to

    constructor: (@row, @col, @chars, @options = {}) ->
      @options.setCursor ?= 'end'
      @options.cursor ?= {}

    str: () ->
      return "row #{@row}, col #{@col}, nchars #{@chars.length}"

    apply: (view) ->
      view.data.writeChars @row, @col, @chars

      shift = if @options.cursor.pastEnd then 1 else 0
      if @options.setCursor == 'beginning'
        view.cursor.set @row, (@col + shift), @options.cursor
      else if @options.setCursor == 'end'
        view.cursor.set @row, (@col + shift + @chars.length - 1), @options.cursor

    rewind: (view) ->
      view.data.deleteChars @row, @col, @chars.length

  class DelChars extends Action
    constructor: (@row, @col, @nchars, @options = {}) ->
      @options.setCursor ?= 'before'
      @options.cursor ?= {}

    str: () ->
      return "row #{@row}, col #{@col}, nchars #{@nchars}"

    apply: (view) ->
      @deletedChars = view.data.deleteChars @row, @col, @nchars
      if @options.setCursor == 'before'
        view.cursor.set @row, @col, @options.cursor
      else if @options.setCursor == 'after'
        view.cursor.set @row, (@col + 1), @options.cursor

    rewind: (view) ->
      view.data.writeChars @row, @col, @deletedChars

  class InsertRow extends Action
    constructor: (@parent, @index) ->

    str: () ->
      return "parent #{@parent} index #{@index}"

    apply: (view) ->
      @newrow = view.data.addChild @parent, @index
      view.cursor.set @newrow, 0

    rewind: (view) ->
      @rewinded = view.data.detach @newrow

    reapply: (view) ->
      view.data.attachChild @parent, @newrow, @index

  class DetachBlock extends Action
    constructor: (@row, @options = {}) ->

    str: () ->
      return "row #{@row}"

    apply: (view) ->
      @parent = view.data.getParent @row
      @index = view.data.indexOf @row

      errors.assert_not_equals @row, view.data.root, "Cannot detach root"

      view.data.detach @row

    rewind: (view) ->
      view.data.attachChild @parent, @row, @index

  class AttachBlock extends Action
    constructor: (@row, @parent, @index = -1, @options = {}) ->

    str: () ->
      return "row #{@row}, parent #{@parent}"

    apply: (view) ->
      view.data.attachChild @parent, @row, @index

    rewind: (view) ->
      view.data.detach @row

  class DeleteBlocks extends Action
    constructor: (@parent, @index, @nrows = 1, @options = {}) ->

    str: () ->
      return "parent #{@parent}, index #{@index}, nrows #{@nrows}"

    apply: (view) ->
      @deleted_rows = []
      delete_rows = view.data.getChildRange @parent, @index, (@index+@nrows-1)
      for sib in delete_rows
        if sib == null then break
        @deleted_rows.push sib
        view.data.detach sib

      @created = null
      if @options.addNew
        @created = view.data.addChild @parent, @index

      children = view.data.getChildren @parent

      if @index < children.length
        next = children[@index]
      else
        next = if @index == 0 then @parent else children[@index - 1]
        if next == view.data.viewRoot
          next = view.data.addChild @parent
          @created = next

      view.cursor.set next, 0

    rewind: (view) ->
      if @created != null
        @created_rewinded = view.data.detach @created
      index = @index
      for row in @deleted_rows
        view.data.attachChild @parent, row, index
        index += 1

    reapply: (view) ->
      for row in @deleted_rows
        view.data.detach row
      if @created != null
        view.data.attachChild @created_rewinded.parent, @created, @created_rewinded.index

  class AddBlocks extends Action
    # options:
    #   setCursor: if you wish to set the cursor, set to 'first' or 'last',
    #              indicating which block the cursor should go to

    constructor: (@serialized_rows, @parent, @index = -1, @options = {}) ->
      @nrows = @serialized_rows.length

    str: () ->
      return "parent #{@parent}, index #{@index}"

    apply: (view) ->
      index = @index

      first = true
      for serialized_row in @serialized_rows
        row = view.data.loadTo serialized_row, @parent, index
        index += 1

        if @options.setCursor == 'first' and first
          view.cursor.set row, 0
          first = false

      if @options.setCursor == 'last'
        view.cursor.set row, 0

    rewind: (view) ->
      @delete_siblings = view.data.getChildRange @parent, @index, (@index + @nrows - 1)
      for sib in @delete_siblings
        view.data.detach sib

    reapply: (view) ->
      index = @index
      for sib in @delete_siblings
        view.data.attachChild @parent, sib, index
        index += 1

  class ToggleBlock extends Action
    constructor: (@row) ->
    str: () ->
      return "row #{@row}"
    apply: (view) ->
      view.data.toggleCollapsed @row
    rewind: (view) ->
      view.data.toggleCollapsed @row

  class SetMark extends Action
    constructor: (@row, @mark) ->
    str: () ->
      return "row #{@row}, mark #{@mark}"
    apply: (view) ->
      @oldmark = view.data.getMark @row
      view.data.setMark @row, @mark
    rewind: (view) ->
      view.data.setMark @row, @oldmark

  exports.AddChars = AddChars
  exports.DelChars = DelChars
  exports.InsertRow = InsertRow
  exports.DetachBlock = DetachBlock
  exports.AttachBlock = AttachBlock
  exports.DeleteBlocks = DeleteBlocks
  exports.AddBlocks = AddBlocks
  exports.ToggleBlock = ToggleBlock
  exports.SetMark = SetMark
)(if typeof exports isnt 'undefined' then exports else window.actions = {})
