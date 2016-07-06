constants = require './constants.coffee'
errors = require './errors.coffee'

# represents a tree-traversal starting from the root going down
# should be immutable
class Path
  constructor: (@parent, @row) ->

  isRoot: () ->
    @row == constants.root_row

  # gets a list of IDs
  getAncestry: () ->
    if do @isRoot then return []
    ancestors = do @parent.getAncestry
    ancestors.push @row
    ancestors

  # length: () ->
  #   if @parent == null
  #     return 0
  #   return 1 + (do @parent.length)

  child: (row) ->
    errors.assert (row != @row)
    new Path @, row

  isDescendant: (other_path) ->
    return (@walkFrom other_path) != null

  walkFrom: (ancestor) ->
    my_ancestry = do @getAncestry
    their_ancestry = do ancestor.getAncestry
    if my_ancestry.length < their_ancestry.length
      return null
    for i in [0...their_ancestry.length]
      if my_ancestry[i] != their_ancestry[i]
        return null
    return my_ancestry.slice their_ancestry.length

  shedUntil: (row) ->
    ancestor = @
    path = []
    while ancestor.row != row
      if !ancestor.parent
        return [null, null]
      path.push ancestor.row
      ancestor = ancestor.parent
    return [path.reverse(), ancestor]

  extend: (walk) ->
    descendent = @
    for row in walk
      descendent = descendent.child row
    return descendent

  # Represents the exact same row
  is: (other) ->
    if @row != other.row then return false
    if do @isRoot then return do other.isRoot
    if do other.isRoot then return false
    return @parent.is other.parent

Path.getRoot = () ->
  new Path null, constants.root_row

Path.loadFromAncestry = (ancestry) ->
  if ancestry.length == 0
    return do Path.getRoot
  row = do ancestry.pop
  parent = Path.loadFromAncestry ancestry
  parent.child row

module.exports = Path
