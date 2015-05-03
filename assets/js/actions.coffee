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
      view.drawRow @row
    rewind: (view) ->
      view.data.deleteChars @row, @col, @chars.length
      view.drawRow @row

  class DelChars extends Action
    constructor: (row, col, nchars, options = {}) ->
      @row = row
      @col = col
      @nchars = nchars
      @options = options
    apply: (view) ->
      @deletedChars = view.data.deleteChars @row, @col, @nchars
      view.setCur @row, @col, @options.cursor
      view.drawRow @row
    rewind: (view) ->
      view.data.writeChars @row, @col, @deletedChars
      view.drawRow @row

  # TODO: make all the `do view.render` more efficient

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
      do view.render

    rewind: (view) ->
      view.data.deleteRow @newrow
      do view.render

  class DeleteRows extends Action
    constructor: (row, nrows, options = {}) ->
      @row = row
      @nrows = nrows
      @options = options

    apply: (view) ->
      # leaves dangling pointers, for both paste and undo
      # these get garbage collected when we serialize/deserialize

      row = @row

      addNew = false
      deleted = []

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
        deleted.push row

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

      view.setCur next, 0
      @deleted = deleted
      @parent = parent
      @index = index

      do view.render

    rewind: (view) ->
      if @created != null
        view.data.deleteRow @created
      view.data.attachChildren @parent, @deleted, @index
      do view.render

  class AttachRow extends Action
    constructor: (parent, row, index = -1) ->
      @parent = parent
      @row = row
      @index = index

    apply: (view) ->
      view.data.attachChild @parent, @row, @index
      do view.render

    rewind: (view) ->
      view.data.detach @row
      do view.render

  class DetachRow extends Action
    constructor: (row) ->
      @row = row

    apply: (view) ->
      @result = view.data.detach @row
      do view.render

    rewind: (view) ->
      view.data.attachChild @result.parent, @row, @result.index
      do view.render

  exports.AddChars = AddChars
  exports.DelChars = DelChars
  exports.InsertRowSibling = InsertRowSibling
  exports.DeleteRows = DeleteRows
  exports.AttachRow = AttachRow
  exports.DetachRow = DetachRow
)(if typeof exports isnt 'undefined' then exports else window.actions = {})
