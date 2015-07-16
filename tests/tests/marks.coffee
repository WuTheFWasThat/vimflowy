require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test marks
t = new TestCase [
  'a line'
  'another line'
]
t.expectMarks {}
t.sendKeys 'mmarktest'
t.sendKey 'enter'
t.expectMarks {'marktest': 1}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  'another line'
]

t.sendKeys 'jmtest2'
t.sendKey 'enter'
t.expectMarks {'marktest': 1, 'test2': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'test2' }
]

# unmark
t.sendKeys 'km'
t.sendKey 'enter'
t.expectMarks {'test2': 2}
t.expect [
  'a line',
  { line: 'another line', children: [], mark: 'test2' }
]

t.sendKeys 'jm'
t.sendKey 'enter'
t.expectMarks {}
t.expect [
  'a line'
  'another line'
]

t.sendKeys 'dd'
t.expect [
  'a line'
]

# undo works
t.sendKeys 'uu'
t.expectMarks {'test2': 2}
t.expect [
  'a line',
  { line: 'another line', children: [], mark: 'test2' }
]

t.sendKeys 'u'
t.expectMarks {'marktest': 1, 'test2': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'test2' }
]

t.sendKeys 'u'
t.expectMarks {'marktest': 1}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  'another line'
]

# redo works
t.sendKey 'ctrl+r'
t.expectMarks {'marktest': 1, 'test2': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'test2' }
]

# backspace and left and right work
t.sendKeys 'mhallo'
t.sendKey 'left'
t.sendKey 'backspace'
t.sendKey 'enter'
t.expectMarks {'marktest': 1, 'halo': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'halo' }
]

# cancel works
t.sendKeys 'mbye'
t.sendKey 'esc'
t.expectMarks {'marktest': 1, 'halo': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'halo' }
]

# WEIRD CASES:

# try to mark again something that's already there
# ???

# delete line with mark
# - should no longer be possible to reference that
# -> detachBlock should remove mark from allMarks

# delete line with mark
# paste line
# - should still have mark

# delete line with mark
# mark with that mark
# paste line
# - should not have mark

# -> attachBlock should try to use mark.  if it doesn't exist, take it.  otherwise, do nothing
