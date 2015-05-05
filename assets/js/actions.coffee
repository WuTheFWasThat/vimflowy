((exports) ->

  # actions mutate the data of a view, and are undoable

  class Action
    apply: (view) ->
      return
    rewind: (view) ->
      return

  class AddChars extends Action
    constructor: (row, col, chars, options = {}) ->
      @row = row
      @col = col
      @chars = chars
      @options = options
    apply: (view) ->
      view.data.writeChars @row, @col, @chars
      view.setCur @row, (@col + @chars.length), @options.cursor
    rewind: (view) ->
      view.data.deleteChars @row, @col, @chars.length

  class DelChars extends Action
    constructor: (row, col, nchars, options = {}) ->
      @row = row
      @col = col
      @nchars = nchars
      @options = options
    apply: (view) ->
      @deletedChars = view.data.deleteChars @row, @col, @nchars
      view.setCur @row, @col, @options.cursor
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
        console.log @options
        throw 'InsertRowSibling needs valid option'
      view.setCur @newrow, 0

    rewind: (view) ->
      view.data.deleteRow @newrow

  class DetachBlocks extends Action
    constructor: (row, nrows = 1, options = {}) ->
      @row = row
      @nrows = nrows
      @options = options

    apply: (view) ->
      # leaves dangling pointers, for both paste and undo
      # these get garbage collected when we serialize/deserialize

      row = @row

      addNew = false
      @deletedRows = []

      @created = null

      parent = view.data.getParent row
      index = view.data.indexOf row

      for i in [1..@nrows]
        if row == view.root
          throw 'Cannot delete root'

        info = view.data.detach row
        if info.index != index
          throw 'expected to delete at index'
        if info.parent != parent
          throw 'expected to delete at parent'
        @deletedRows.push row

        siblings = view.data.getChildren parent
        if index < siblings.length # keep deleting!
          if i == @nrows and @options.addNew
              next = view.data.addChild parent, index
              @created = next
          else
              next = siblings[index]
        else # stop deleting
          if index > 0
            next = siblings[index - 1]
          else
            next = parent
          if @options.addNew or (next == view.data.root)
              next = view.data.addChild parent
              @created = next
          break

        row = next

      if @options.cursor != 'stay'
        view.setCur next, 0
      @parent = parent
      @index = index

    rewind: (view) ->
      if @created != null
        view.data.deleteRow @created
      view.data.attachChildren @parent, @deletedRows, @index

  class AttachBlocks extends Action
    constructor: (parent, rows, index = -1, options = {}) ->
      @parent = parent
      @rows = rows
      @index = index
      @options = options

    apply: (view) ->
      view.data.attachChildren @parent, @rows, @index

      if @options.cursor != 'stay'
        view.setCur @rows[0], 0

    rewind: (view) ->
      for row in @rows
        view.data.detach row

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
  exports.DetachBlocks = DetachBlocks
  exports.AttachBlocks = AttachBlocks
  exports.ToggleBlock = ToggleBlock
)(if typeof exports isnt 'undefined' then exports else window.actions = {})
