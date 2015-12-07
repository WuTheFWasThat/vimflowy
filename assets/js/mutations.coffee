###
mutations mutate the data of a view, and are undoable
each mutation should implement a constructor, as well as the following methods:

    str: () -> string
        prints itself
    mutate: (view) -> void
        takes a view and acts on it (mutates the view)
    rewind: (view) -> void
        takes a view, assumed be in the state right after the mutation was applied, and undoes the mutation

the mutation may also optionally implement

    validate: (view) -> bool
        returns whether this action is valid at the time (i.e. whether it is okay to call mutate)
    remutate: (view) -> void
        takes a view, and acts on it.  assumes that mutate has been called once already
        by default, remutate is the same as mutate.
        it should be implemented only if it is more efficient than the mutate implementation
###

if module?
  global._ = require('lodash')
  global.errors = require('./errors.coffee')

((exports) ->

  # validate inserting id as a child of parent_id
  validateRowInsertion = (view, parent_id, id, options={}) ->
    # check that there won't be doubled siblings
    if not options.noSiblingCheck
      if view.data._hasChild parent_id, id
        view.showMessage "Cloned rows cannot be inserted as siblings", {text_class: 'error'}
        return false

    # check that there are no cycles
    # Precondition: tree is not already circular
    # It is sufficient to check if the row is an ancestor of the new parent,
    # because if there was a clone underneath the row which was an ancestor of 'parent',
    # then 'row' would also be an ancestor of 'parent'.
    if _.contains (view.data.allAncestors parent_id, { inclusive: true }), id
      view.showMessage "Cloned rows cannot be nested under themselves", {text_class: 'error'}
      return false
    return true

  class Mutation
    str: () ->
      return ''
    validate: (view) ->
      return true
    mutate: (view) ->
      return
    rewind: (view) ->
      return
    remutate: (view) ->
      return @mutate view

  class AddChars extends Mutation
    # options:
    #   setCursor: if you wish to set the cursor, set to 'beginning' or 'end'
    #              indicating where the cursor should go to

    constructor: (@row, @col, @chars, @options = {}) ->
      @options.setCursor ?= 'end'
      @options.cursor ?= {}

    str: () ->
      return "row #{@row.id}, col #{@col}, nchars #{@chars.length}"

    mutate: (view) ->
      view.data.writeChars @row, @col, @chars

      shift = if @options.cursor.pastEnd then 1 else 0
      if @options.setCursor == 'beginning'
        view.cursor.set @row, (@col + shift), @options.cursor
      else if @options.setCursor == 'end'
        view.cursor.set @row, (@col + shift + @chars.length - 1), @options.cursor

    rewind: (view) ->
      view.data.deleteChars @row, @col, @chars.length

  class DelChars extends Mutation
    constructor: (@row, @col, @nchars, @options = {}) ->
      @options.setCursor ?= 'before'
      @options.cursor ?= {}

    str: () ->
      return "row #{@row.id}, col #{@col}, nchars #{@nchars}"

    mutate: (view) ->
      @deletedChars = view.data.deleteChars @row, @col, @nchars
      if @options.setCursor == 'before'
        view.cursor.set @row, @col, @options.cursor
      else if @options.setCursor == 'after'
        view.cursor.set @row, (@col + 1), @options.cursor

    rewind: (view) ->
      view.data.writeChars @row, @col, @deletedChars

  class MoveBlock extends Mutation
    constructor: (@row, @parent, @index = -1, @options = {}) ->
      @old_parent = do @row.getParent

    str: () ->
      return "row #{@row.id} from #{@row.parent.id} to #{@parent.id}"

    validate: (view) ->
      # if parent is the same, don't do sibling clone validation
      sameParent = @parent.id == @old_parent.id
      return (validateRowInsertion view, @parent.id, @row.id, {noSiblingCheck: sameParent})

    mutate: (view) ->
      errors.assert (not do @row.isRoot), "Cannot detach root"
      info = view.data._move @row.id, @old_parent.id, @parent.id, @index
      @old_index = info.old.childIndex
      @row.setParent @parent

    rewind: (view) ->
      view.data._move @row.id, @parent.id, @old_parent.id, @old_index
      @row.setParent @old_parent

  class AttachBlocks extends Mutation
    # options:
    #   setCursor: if you wish to set the cursor, set to 'first' or 'last',
    #              indicating which block the cursor should go to

    constructor: (@parent, @cloned_rows, @index = -1, @options = {}) ->
      @nrows = @cloned_rows.length

    str: () ->
      return "parent #{@parent.id}, index #{@index}"

    validate: (view) ->
      for id in @cloned_rows
        if not (validateRowInsertion view, @parent.id, id)
          return false
      return true

    mutate: (view) ->
      view.data._attachChildren @parent.id, @cloned_rows, @index

      if @options.setCursor == 'first'
        view.cursor.set (view.data.findChild @parent, @cloned_rows[0]), 0
      else if @options.setCursor == 'last'
        view.cursor.set (view.data.findChild @parent, @cloned_rows[@cloned_rows.length-1]), 0

    rewind: (view) ->
      delete_siblings = view.data.getChildRange @parent, @index, (@index + @nrows - 1)
      for sib in delete_siblings
        view.data.detach sib

  class DetachBlocks extends Mutation
    constructor: (@parent, @index, @nrows = 1, @options = {}) ->

    str: () ->
      return "parent #{@parent.id}, index #{@index}, nrows #{@nrows}"

    mutate: (view) ->
      @deleted = []
      delete_rows = view.data.getChildRange @parent, @index, (@index+@nrows-1)
      for sib in delete_rows
        if sib == null then break
        view.data.detach sib
        @deleted.push sib.id

      @created = null
      if @options.addNew
        @created = view.data.addChild @parent, @index

      children = view.data.getChildren @parent

      if @index < children.length
        next = children[@index]
      else
        next = if @index == 0 then @parent else children[@index - 1]
        if next.id == view.data.viewRoot.id
          unless @options.noNew
            next = view.data.addChild @parent
            @created = next

      view.cursor.set next, 0

    rewind: (view) ->
      if @created != null
        @created_rewinded = view.data.detach @created
      index = @index
      view.data._attachChildren @parent.id, @deleted, index

    remutate: (view) ->
      for id in @deleted
        view.data._detach id, @parent.id
      if @created != null
        view.data.attachChild @created_rewinded.parent, @created, @created_rewinded.index

  # creates new blocks (as opposed to attaching ones that already exist)
  class AddBlocks extends Mutation
    # options:
    #   setCursor: if you wish to set the cursor, set to 'first' or 'last',
    #              indicating which block the cursor should go to

    constructor: (@parent, @index = -1, @serialized_rows, @options = {}) ->
      @nrows = @serialized_rows.length

    str: () ->
      return "parent #{@parent.id}, index #{@index}"

    mutate: (view) ->
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

    remutate: (view) ->
      index = @index
      for sib in @delete_siblings
        view.data.attachChild @parent, sib, index
        index += 1

  class ToggleBlock extends Mutation
    constructor: (@row) ->
    str: () ->
      return "row #{@row.id}"
    mutate: (view) ->
      view.data.toggleCollapsed @row
    rewind: (view) ->
      view.data.toggleCollapsed @row

  exports.Mutation = Mutation

  exports.AddChars = AddChars
  exports.DelChars = DelChars
  exports.AddBlocks = AddBlocks
  exports.DetachBlocks = DetachBlocks
  exports.AttachBlocks = AttachBlocks
  exports.MoveBlock = MoveBlock
  exports.ToggleBlock = ToggleBlock
)(if typeof exports isnt 'undefined' then exports else window.mutations = {})
