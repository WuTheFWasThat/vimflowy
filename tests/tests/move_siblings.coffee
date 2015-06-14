require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test alt+j and alt+k
t = new TestCase [
  { line: 'one', children: [
    'uno',
  ] }
  { line: 'two', children: [
    'dos',
  ] }
  { line: 'tacos', children: [
    'tacos',
  ] }
]
t.sendKeys 'x'
t.sendKey 'alt+j'
t.sendKeys 'x'
t.expect [
  { line: 'ne', children: [
    'uno',
  ] }
  { line: 'wo', children: [
    'dos',
  ] }
  { line: 'tacos', children: [
    'tacos',
  ] }
]
t.sendKey 'alt+j'
t.sendKeys 'x'
t.sendKey 'alt+j'
t.sendKeys 'x'
t.expect [
  { line: 'ne', children: [
    'uno',
  ] }
  { line: 'wo', children: [
    'dos',
  ] }
  { line: 'cos', children: [
    'tacos',
  ] }
]
t.sendKey 'alt+k'
t.sendKeys 'x'
t.expect [
  { line: 'ne', children: [
    'uno',
  ] }
  { line: 'o', children: [
    'dos',
  ] }
  { line: 'cos', children: [
    'tacos',
  ] }
]
t.sendKey 'alt+k'
t.sendKeys 'x'
t.expect [
  { line: 'e', children: [
    'uno',
  ] }
  { line: 'o', children: [
    'dos',
  ] }
  { line: 'cos', children: [
    'tacos',
  ] }
]
t.sendKey 'alt+k'
t.sendKeys 'x'
t.expect [
  { line: '', children: [
    'uno',
  ] }
  { line: 'o', children: [
    'dos',
  ] }
  { line: 'cos', children: [
    'tacos',
  ] }
]

