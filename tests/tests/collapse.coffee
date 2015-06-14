require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test collapsing
t = new TestCase [
  { line: 'first', children: [
    'second'
  ] },
  'third'
]
t.sendKeys 'z'
t.expect [
  { line: 'first', collapsed: true, children: [
    'second'
  ] },
  'third'
]
t.sendKeys 'jx'
t.expect [
  { line: 'first', collapsed: true, children: [
    'second'
  ] },
  'hird'
]
t.sendKeys 'uu'
t.expect [
  { line: 'first', children: [
    'second'
  ] },
  'third'
]

