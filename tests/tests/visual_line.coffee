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

# yank doesn't save
t = new TestCase [ '1', '2' ]
t.sendKeys 'xjVy'
t.expect [ '', '2' ]
t.sendKeys '.' # this is the x, not the y
t.expect [ '', '' ]

# test children
t = new TestCase [
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
  ] }
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]
t.sendKeys 'Vjx'
t.expect [
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]
t.sendKeys 'p'
t.expect [
  { text: 'nest 3', children: [
    { text: 'nest', children: [
      'egg'
    ] }
    { text: 'nest 2', children: [
      'egg 2'
    ] }
    'egg 3'
  ] }
]
# ends up on row 2
t.sendKeys 'Vjjdp'
t.expect [
  'nest 3'
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
  ] }
  'egg 3'
]
# ends up on row 2
t.sendKeys 'x'
t.expect [
  'nest 3'
  { text: 'est', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
  ] }
  'egg 3'
]
t.sendKeys 'u'
t.expect [
  'nest 3'
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
  ] }
  'egg 3'
]
t.sendKeys 'u'
t.expect [ 'nest 3' ]
t.sendKeys 'u'
t.expect [
  { text: 'nest 3', children: [
    { text: 'nest', children: [
      'egg'
    ] }
    { text: 'nest 2', children: [
      'egg 2'
    ] }
    'egg 3'
  ] }
]
t.sendKeys 'u'
t.expect [
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]
t.sendKeys 'u'
t.expect [
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
  ] }
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]

# test indent
t = new TestCase [
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
    'egg 2 2'
  ] }
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]
# does nothing when can't indent
t.sendKeys 'jVj>'
t.expect [
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
    'egg 2 2'
  ] }
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]
# now can indent
t.sendKeys 'jVj>'
t.expect [
  { text: 'nest', children: [
    'egg'
    { text: 'nest 2', children: [
      'egg 2'
      'egg 2 2'
    ] }
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ] }
]
# does nothing again
t.sendKeys 'jV>'
t.expect [
  { text: 'nest', children: [
    'egg'
    { text: 'nest 2', children: [
      'egg 2'
      'egg 2 2'
    ] }
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ] }
]
# unindent
t.sendKeys 'V<'
t.expect [
  { text: 'nest', children: [
    'egg'
    { text: 'nest 2', children: [
      'egg 2 2'
    ] }
    'egg 2'
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ] }
]
# undo ignores things that didn't happen
t.sendKeys 'u'
t.expect [
  { text: 'nest', children: [
    'egg'
    { text: 'nest 2', children: [
      'egg 2'
      'egg 2 2'
    ] }
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ] }
]
t.sendKeys 'u'
t.expect [
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
    'egg 2 2'
  ] }
  { text: 'nest 3', children: [
    'egg 3'
  ] }
]
