errors = require './errors.coffee'

###
mutations mutate a document within a session, and are undoable
each mutation should implement a constructor, as well as the following methods:

    str: () -> string
        prints itself
    mutate: (session) -> void
        takes a session and acts on it (mutates the session)
    rewind: (session) -> void
        takes a session, assumed be in the state right after the mutation was applied, and undoes the mutation

the mutation may also optionally implement

    validate: (session) -> bool
        returns whether this action is valid at the time (i.e. whether it is okay to call mutate)
    remutate: (session) -> void
        takes a session, and acts on it.  assumes that mutate has been called once already
        by default, remutate is the same as mutate.
        it should be implemented only if it is more efficient than the mutate implementation
    moveCursor: (cursor) -> void
        takes a cursor, and moves it according to how the cursor should move
###

_ = require 'lodash'
errors = require './errors.coffee'

# validate inserting id as a child of parent_id
validateRowInsertion = (session, parent_id, id, options={}) ->
  # check that there won't be doubled siblings
  if not options.noSiblingCheck
    if session.document._hasChild parent_id, id
      session.showMessage "Cloned rows cannot be inserted as siblings", {text_class: 'error'}
      return false

  # check that there are no cycles
  # Precondition: tree is not already circular
  # It is sufficient to check if the row is an ancestor of the new parent,
  # because if there was a clone underneath the row which was an ancestor of 'parent',
  # then 'row' would also be an ancestor of 'parent'.
  if _.includes (session.document.allAncestors parent_id, { inclusive: true }), id
    session.showMessage "Cloned rows cannot be nested under themselves", {text_class: 'error'}
    return false
  return true

class Mutation
  str: () ->
    return ''
  validate: (session) ->
    return true
  mutate: (session) ->
    return
  rewind: (session) ->
    return
  remutate: (session) ->
    return @mutate session
  moveCursor: (cursor) ->
    return

class AddChars extends Mutation
  constructor: (@row, @col, @chars) ->

  str: () ->
    return "row #{@row.row}, col #{@col}, nchars #{@chars.length}"

  mutate: (session) ->
    session.document.writeChars @row.row, @col, @chars

  rewind: (session) ->
    session.document.deleteChars @row.row, @col, @chars.length

  moveCursor: (cursor) ->
    if not (cursor.path.is @row)
      return
    if cursor.col >= @col
      cursor.setCol (cursor.col + @chars.length)

class DelChars extends Mutation
  constructor: (@row, @col, @nchars) ->

  str: () ->
    return "row #{@row}, col #{@col}, nchars #{@nchars}"

  mutate: (session) ->
    @deletedChars = session.document.deleteChars @row, @col, @nchars

  rewind: (session) ->
    session.document.writeChars @row, @col, @deletedChars

  moveCursor: (cursor) ->
    if cursor.row != @row
      return
    if cursor.col < @col
      return
    else if cursor.col < @col + @nchars
      cursor.setCol @col
    else
      cursor.setCol (cursor.col - @nchars)

class ChangeChars extends Mutation
  constructor: (@row, @col, @nchars, @transform) ->

  str: () ->
    return "change row #{@row}, col #{@col}, nchars #{@nchars}"

  mutate: (session) ->
    @deletedChars = session.document.deleteChars @row, @col, @nchars
    @ncharsDeleted = @deletedChars.length
    @addedChars = @transform @deletedChars
    errors.assert (@addedChars.length == @ncharsDeleted)
    session.document.writeChars @row, @col, @addedChars

  rewind: (session) ->
    session.document.deleteChars @row, @col, @ncharsDeleted
    session.document.writeChars @row, @col, @deletedChars

  remutate: (session) ->
    session.document.deleteChars @row, @col, @ncharsDeleted
    session.document.writeChars @row, @col, @addedChars

  # doesn't move cursors

class MoveBlock extends Mutation
  constructor: (@path, @parent, @index = -1) ->
    @old_parent = @path.parent

  str: () ->
    return "path #{@path.row} from #{@path.parent.row} to #{@parent.row}"

  validate: (session) ->
    # if parent is the same, don't do sibling clone validation
    sameParent = @parent.row == @old_parent.row
    return (validateRowInsertion session, @parent.row, @path.row, {noSiblingCheck: sameParent})

  mutate: (session) ->
    errors.assert (not do @path.isRoot), "Cannot detach root"
    info = session.document._move @path.row, @old_parent.row, @parent.row, @index
    @old_index = info.old.childIndex

  rewind: (session) ->
    session.document._move @path.row, @parent.row, @old_parent.row, @old_index

  moveCursor: (cursor) ->
    walk = cursor.path.walkFrom @path
    if walk == null
      return
    cursor._setPath (@parent.extend [@path.row]).extend walk

class AttachBlocks extends Mutation
  constructor: (@parent, @cloned_rows, @index = -1, @options = {}) ->
    @nrows = @cloned_rows.length

  str: () ->
    return "parent #{@parent}, index #{@index}"

  validate: (session) ->
    for row in @cloned_rows
      if not (validateRowInsertion session, @parent, row)
        return false
    return true

  mutate: (session) ->
    session.document._attachChildren @parent, @cloned_rows, @index

  rewind: (session) ->
    delete_siblings = session.document._getChildRange @parent, @index, (@index + @nrows - 1)
    for sib in delete_siblings
      session.document._detach sib, @parent

class DetachBlocks extends Mutation
  constructor: (@parent, @index, @nrows = 1, @options = {}) ->

  str: () ->
    return "parent #{@parent.row}, index #{@index}, nrows #{@nrows}"

  mutate: (session) ->
    @deleted = []
    delete_rows = session.document.getChildRange @parent, @index, (@index+@nrows-1)
    for sib in delete_rows
      if sib == null then break
      session.document.detach sib
      @deleted.push sib.row

    @created = null
    if @options.addNew
      @created = session.document.addChild @parent, @index

    children = session.document.getChildren @parent

    if @index < children.length
      next = children[@index]
    else
      if @index == 0
        next = @parent
      else
        next = session.lastVisible children[@index - 1]

      if next.row == session.document.root.row
        unless @options.noNew
          next = session.document.addChild @parent
          @created = next

    @next = next

  rewind: (session) ->
    if @created != null
      @created_rewinded = session.document.detach @created
    index = @index
    session.document._attachChildren @parent.row, @deleted, index

  remutate: (session) ->
    for row in @deleted
      session.document._detach row, @parent.row
    if @created != null
      session.document.attachChild @created_rewinded.parent, @created, @created_rewinded.index

  moveCursor: (cursor) ->
    walk = cursor.path.walkFrom @parent
    if walk == null
      return
    if (@deleted.indexOf walk[0]) == -1
      return

    cursor.set @next, 0

# creates new blocks (as opposed to attaching ones that already exist)
class AddBlocks extends Mutation
  # options:
  #   setCursor: if you wish to set the cursor, set to 'first' or 'last',
  #              indicating which block the cursor should go to

  constructor: (@parent, @index = -1, @serialized_rows, @options = {}) ->
    @nrows = @serialized_rows.length

  str: () ->
    return "parent #{@parent.row}, index #{@index}"

  mutate: (session) ->
    index = @index

    first = true
    id_mapping = {}
    for serialized_row in @serialized_rows
      row = session.document.loadTo serialized_row, @parent, index, id_mapping
      index += 1

      if @options.setCursor == 'first' and first
        session.cursor.set row, 0, @options.cursorOptions
        first = false

    if @options.setCursor == 'last'
      session.cursor.set row, 0, @options.cursorOptions

  rewind: (session) ->
    @delete_siblings = session.document.getChildRange @parent, @index, (@index + @nrows - 1)
    for sib in @delete_siblings
      session.document.detach sib

  remutate: (session) ->
    index = @index
    for sib in @delete_siblings
      session.document.attachChild @parent, sib, index
      index += 1

class ToggleBlock extends Mutation
  constructor: (@row) ->
  str: () ->
    return "row #{@row}"
  mutate: (session) ->
    session.document.toggleCollapsed @row
  rewind: (session) ->
    session.document.toggleCollapsed @row

exports.Mutation = Mutation

exports.AddChars = AddChars
exports.DelChars = DelChars
exports.ChangeChars = ChangeChars
exports.AddBlocks = AddBlocks
exports.DetachBlocks = DetachBlocks
exports.AttachBlocks = AttachBlocks
exports.MoveBlock = MoveBlock
exports.ToggleBlock = ToggleBlock
