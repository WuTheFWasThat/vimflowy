_ = require 'lodash'

# takes a constructor and returns an error class
errorFactory = (f) ->
  g = () ->
    @stack = new Error().stack
    f.apply @, arguments
  g.prototype = Object.create(Error.prototype)
  return g

exports.NotImplemented = errorFactory (message) -> @message = "Not implemented!"
exports.UnexpectedValue = errorFactory (name, value) -> @message = "Unexpected value for `#{name}`: #{value}"
exports.GenericError = errorFactory (@message) -> return
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

# for asserting object equality
exports.assert_deep_equals = (a, b, message="assert_deep_equals error") ->
  if not _.isEqual a, b
    throw new AssertionError "#{message}
      \nExpected:
      \n#{JSON.stringify(a, null, 2)}
      \nBut got:
      \n#{JSON.stringify(b, null, 2)}
    "
    throw new Error message

exports.assert_arrays_equal = (arr_a, arr_b) ->
  a_minus_b = _.difference(arr_a, arr_b)
  if a_minus_b.length then throw new AssertionError "Arrays not same, first contains: #{a_minus_b}"
  b_minus_a = _.difference(arr_b, arr_a)
  if b_minus_a.length then throw new AssertionError "Arrays not same, second contains: #{b_minus_a}"
