if module? # imports
  global._ = require('lodash')

((exports) ->

  # takes a constructor and returns an error class
  errorFactory = (f) ->
    f.prototype = new Error()
    return f

  exports.NotImplemented = errorFactory (message) -> @message = "Not implemented!"
  exports.UnexpectedValue = errorFactory (name, value) -> @message = "Unexpected value for `#{name}`: #{value}"
  exports.GenericError = errorFactory (@message) -> return
  exports.CircularReference = errorFactory (@message) -> return
  exports.SchemaVersion = errorFactory (@message) -> return

  # is special because ignored by error handling in index.coffee
  exports.DataPoisoned = errorFactory (@message) -> return

  ##########
  # asserts
  ##########

  AssertionError = errorFactory (message) -> @message = "Assertion error: #{message}"
  exports.AssertionError = AssertionError

  exports.assert = (a, message="assert error") ->
    unless a then throw new AssertionError "#{message}\nExpected #{a} to be true"

  exports.assert_equals = (a, b, message="assert_equals error") ->
    if a != b then throw new AssertionError "#{message}\nExpected #{a} == #{b}"

  exports.assert_not_equals = (a, b, message="assert_not_equals error") ->
    if a == b then throw new AssertionError "#{message}\nExpected #{a} != #{b}"

  exports.assert_arrays_equal = (arr_a, arr_b) ->
    a_minus_b = _.difference(arr_a, arr_b)
    if a_minus_b.length then throw new AssertionError "Arrays not same, first contains: #{a_minus_b}"
    b_minus_a = _.difference(arr_b, arr_a)
    if b_minus_a.length then throw new AssertionError "Arrays not same, second contains: #{b_minus_a}"

)(if typeof exports isnt 'undefined' then exports else window.errors = {})
