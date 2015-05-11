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
      if @options.cursor != 'stay'
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
      siblings = view.data.getChildren parent

      if row == view.root then throw 'Cannot delete root'

      @serialized_rows = []
      delete_siblings = view.data.getSiblingRange row, 0, (@nrows-1)
      for sib in delete_siblings
        if sib == null then break
        @serialized_rows.push view.data.serialize sib
        view.data.deleteRow sib

      @created = null
      if @options.addNew
        @created = view.data.addChild parent, index

      if index < siblings.length
        next = siblings[index]
      else
        next = if index == 0 then parent else siblings[index - 1]
        if next == view.data.root
          next = view.data.addChild parent
          @created = next

      if @options.cursor != 'stay'
        view.setCur next, 0
      @parent = parent
      @index = index

    rewind: (view) ->
      if @created != null
        view.data.deleteRow @created
      index = @index
      for serialized_row in @serialized_rows
        view.data.loadTo serialized_row, @parent, index
        index += 1

  class AddBlocks extends Action
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

        if @options.cursor == 'first' and first
          view.setCur row, 0
          first = false

      if @options.cursor == 'last'
        view.setCur row, 0

    rewind: (view) ->
      delete_siblings = view.data.getChildRange @parent, @index, (@index + @nrows - 1)
      for sib in delete_siblings
        view.data.deleteRow sib

  class ToggleBlock extends Action
    constructor: (row) ->
      @row = row
    apply: (view) ->
      view.data.toggleCollapsed @row
    rewind: (view) ->
      view.data.toggleCollapsed @row

  class ChangeView extends Action
    constructor: (root) ->
      @newroot = root
    apply: (view) ->
      @oldroot = view.data.root
      view.data.changeViewRoot @newroot
    rewind: (view) ->
      view.data.changeViewRoot @oldroot

  exports.AddChars = AddChars
  exports.DelChars = DelChars
  exports.InsertRowSibling = InsertRowSibling
  exports.DetachBlock = DetachBlock
  exports.AttachBlock = AttachBlock
  exports.DeleteBlocks = DeleteBlocks
  exports.AddBlocks = AddBlocks
  exports.ToggleBlock = ToggleBlock
  exports.ChangeView = ChangeView
)(if typeof exports isnt 'undefined' then exports else window.actions = {})
