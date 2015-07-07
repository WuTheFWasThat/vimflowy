((exports) ->

  # actions mutate the data of a view, and are undoable

  class Action
    apply: (view) ->
      return
    rewind: (view) ->
      return
    reapply: (view) ->
      return @apply view

  class AddChars extends Action
    # options:
    #   setCur: if you wish to set the cursor, set to 'beginning' or 'end'
    #           indicating where the cursor should go to

    constructor: (row, col, chars, options = {}) ->
      @row = row
      @col = col
      @chars = chars

      @options = options
      @options.setCursor ?= 'end'
      @options.cursor ?= {}

    apply: (view) ->
      view.data.writeChars @row, @col, @chars

      shift = if @options.cursor.pastEnd then 1 else 0
      if @options.setCursor == 'beginning'
        view.setCur @row, (@col + shift), @options.cursor
      else if @options.setCursor == 'end'
        view.setCur @row, (@col + shift + @chars.length - 1), @options.cursor
    rewind: (view) ->
      view.data.deleteChars @row, @col, @chars.length

  class DelChars extends Action
    constructor: (row, col, nchars, options = {}) ->
      @row = row
      @col = col
      @nchars = nchars

      @options = options
      @options.setCursor ?= 'before'
    apply: (view) ->
      @deletedChars = view.data.deleteChars @row, @col, @nchars
      if @options.setCursor == 'before'
        view.setCur @row, @col, @options.cursor
      else if @options.setCursor == 'after'
        view.setCur @row, (@col + 1), @options.cursor
    rewind: (view) ->
      view.data.writeChars @row, @col, @deletedChars

  class InsertRowSibling extends Action
    constructor: (row, options) ->
      @row = row
      @options = options

    apply: (view) ->
      if @options.after
        @newrow = view.data.insertSiblingAfter @row
      else if @options.before
        @newrow = view.data.insertSiblingBefore @row
      else
        throw ('InsertRowSibling needs valid options: ' + JSON.stringify @options)
      view.setCur @newrow, 0

    rewind: (view) ->
      @rewinded = view.data.detach @newrow

    reapply: (view) ->
      view.data.attachChild @rewinded.parent, @newrow, @rewinded.index

  class DetachBlock extends Action
    constructor: (row, options = {}) ->
      @row = row
      @options = options

    apply: (view) ->
      @parent = view.data.getParent @row
      @index = view.data.indexOf @row

      if @row == view.root then throw 'Cannot delete root'

      view.data.detach @row

    rewind: (view) ->
      view.data.attachChild @parent, @row, @index

  class AttachBlock extends Action
    constructor: (row, parent, index = -1, options = {}) ->
      @row = row
      @parent = parent
      @index = index
      @options = options

    apply: (view) ->
      view.data.attachChild @parent, @row, @index

    rewind: (view) ->
      view.data.detach @row

  class DeleteBlocks extends Action
    constructor: (row, nrows = 1, options = {}) ->
      @row = row
      @nrows = nrows
      @options = options

    apply: (view) ->
      row = @row
      parent = view.data.getParent row
      index = view.data.indexOf row

      if row == view.root then throw 'Cannot delete root'

      @serialized_rows = []
      @deleted_rows = []
      delete_siblings = view.data.getSiblingRange row, 0, (@nrows-1)
      for sib in delete_siblings
        if sib == null then break
        @serialized_rows.push view.data.serialize sib
        @deleted_rows.push sib
        view.data.detach sib

      @created = null
      if @options.addNew
        @created = view.data.addChild parent, index

      siblings = view.data.getChildren parent

      if index < siblings.length
        next = siblings[index]
      else
        next = if index == 0 then parent else siblings[index - 1]
        if next == view.data.viewRoot
          next = view.data.addChild parent
          @created = next

      view.setCur next, 0
      @parent = parent
      @index = index

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
    #   setCur: if you wish to set the cursor, set to 'first' or 'last',
    #           indicating which block the cursor should go to

    constructor: (serialized_rows, parent, index = -1, options = {}) ->
      @serialized_rows = serialized_rows
      @parent = parent
      @index = index
      @nrows = serialized_rows.length
      @options = options

    apply: (view) ->
      index = @index

      first = true
      for serialized_row in @serialized_rows
        row = view.data.loadTo serialized_row, @parent, index
        index += 1

        if @options.setCursor == 'first' and first
          view.setCur row, 0
          first = false

      if @options.setCursor == 'last'
        view.setCur row, 0

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
    constructor: (row) ->
      @row = row
    apply: (view) ->
      view.data.toggleCollapsed @row
    rewind: (view) ->
      view.data.toggleCollapsed @row

  exports.AddChars = AddChars
  exports.DelChars = DelChars
  exports.InsertRowSibling = InsertRowSibling
  exports.DetachBlock = DetachBlock
  exports.AttachBlock = AttachBlock
  exports.DeleteBlocks = DeleteBlocks
  exports.AddBlocks = AddBlocks
  exports.ToggleBlock = ToggleBlock
)(if typeof exports isnt 'undefined' then exports else window.actions = {})
