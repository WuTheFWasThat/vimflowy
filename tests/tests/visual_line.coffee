require 'coffee-script/register'
TestCase = require '../testcase.coffee'

t = new TestCase [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]
t.sendKeys 'Vjx'
t.expect [ 'i', 'am', 'a', 'test', 'case' ]
t.sendKeys 'u'
t.expect [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]

t = new TestCase [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]
t.sendKeys 'GVkc'
t.expect [ 'hello', 'world', 'i', 'am', 'a', '']
t.sendKeys 'confused soul'
t.expect [ 'hello', 'world', 'i', 'am', 'a', 'confused soul' ]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]

# test o
t = new TestCase [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]
t.sendKeys 'jjjx'
t.expect [ 'hello', 'world', 'i', 'm', 'a', 'test', 'case' ]
t.sendKeys 'Vjjokkd'
t.expect [ 'hello', 'case' ]
t.sendKeys 'u'
t.expect [ 'hello', 'world', 'i', 'm', 'a', 'test', 'case' ]
t.sendKey 'ctrl+r'
t.expect [ 'hello', 'case' ]

# test repeat
t = new TestCase [ '1', '2', '3', '4', '5', '6', '7' ]
t.sendKeys 'Vjjx'
t.expect [ '4', '5', '6', '7' ]
t.sendKeys '.'
t.expect [ '7' ]

# test children
t = new TestCase [
  { line: 'nest', children: [
    'egg'
  ] }
  { line: 'nest 2', children: [
    'egg 2'
  ] }
  { line: 'nest 3', children: [
    'egg 3'
  ] }
]
t.sendKeys 'Vjx'
t.expect [
  { line: 'nest 3', children: [
    'egg 3'
  ] }
]
t.sendKeys 'p'
t.expect [
  { line: 'nest 3', children: [
    { line: 'nest', children: [
      'egg'
    ] }
    { line: 'nest 2', children: [
      'egg 2'
    ] }
    'egg 3'
  ] }
]
# ends up on row 2
t.sendKeys 'Vjjdp'
t.expect [
  'nest 3'
  { line: 'nest', children: [
    'egg'
  ] }
  { line: 'nest 2', children: [
    'egg 2'
  ] }
  'egg 3'
]
# ends up on row 2
t.sendKeys 'x'
t.expect [
  'nest 3'
  { line: 'est', children: [
    'egg'
  ] }
  { line: 'nest 2', children: [
    'egg 2'
  ] }
  'egg 3'
]
t.sendKeys 'u'
t.expect [
  'nest 3'
  { line: 'nest', children: [
    'egg'
  ] }
  { line: 'nest 2', children: [
    'egg 2'
  ] }
  'egg 3'
]
t.sendKeys 'u'
t.expect [ 'nest 3' ]
t.sendKeys 'u'
t.expect [
  { line: 'nest 3', children: [
    { line: 'nest', children: [
      'egg'
    ] }
    { line: 'nest 2', children: [
      'egg 2'
    ] }
    'egg 3'
  ] }
]
t.sendKeys 'u'
t.expect [
  { line: 'nest 3', children: [
    'egg 3'
  ] }
]
t.sendKeys 'u'
t.expect [
  { line: 'nest', children: [
    'egg'
  ] }
  { line: 'nest 2', children: [
    'egg 2'
  ] }
  { line: 'nest 3', children: [
    'egg 3'
  ] }
]
