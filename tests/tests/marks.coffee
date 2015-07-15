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
t.sendKeys 'm'
t.sendKey 'enter'
t.expectMarks {'marktest': 1}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  'another line'
]

t.sendKeys 'km'
t.sendKey 'enter'
t.expectMarks {}
t.expect [
  'a line'
  'another line'
]
