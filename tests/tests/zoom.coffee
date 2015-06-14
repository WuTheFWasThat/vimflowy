require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test changing view root
t = new TestCase [
  { line: 'first', children: [
    'second'
  ] },
  'third'
]
t.sendKey ']'
t.expect [
  { line: 'first', children: [
    'second'
  ] },
  'third'
]
t.sendKeys 'jjx'
t.expect [
  { line: 'first', children: [
    'econd'
  ] },
  'third'
]
# zoom out stays on same line
t.sendKey '['
t.sendKeys 'x'
t.expect [
  { line: 'first', children: [
    'cond'
  ] },
  'third'
]
t.sendKeys 'jx'
t.expect [
  { line: 'first', children: [
    'cond'
  ] },
  'hird'
]

# zoom in on collapsed works but doesn't uncollapse
t = new TestCase [
  { line: 'first', children: [
    { line: 'second', children: [
      'third'
    ] },
  ] },
]
t.sendKeys 'zjx'
t.expect [
  { line: 'irst', collapsed: true, children: [
    { line: 'second', children: [
      'third'
    ] },
  ] },
]
t.sendKeys ']x'
t.expect [
  { line: 'irst', collapsed: true, children: [
    { line: 'econd', children: [
      'third'
    ] },
  ] },
]
# but now zoom out moves the cursor, since otherwise it's hidden
t.sendKeys '[x'
t.expect [
  { line: 'rst', collapsed: true, children: [
    { line: 'econd', children: [
      'third'
    ] },
  ] },
]

# can't unindent too far out when zoomed in
t = new TestCase [
  { line: 'first', children: [
    { line: 'second', children: [
      'third'
    ] },
  ] },
]
t.sendKeys 'jj'
t.sendKey 'shift+tab'
t.expect [
  { line: 'first', children: [
    'second'
    'third'
  ] },
]
t.sendKey 'u'
t.sendKey ']'
t.sendKey 'shift+tab'
t.expect [
  { line: 'first', children: [
    { line: 'second', children: [
      'third'
    ] },
  ] },
]

