require 'coffee-script/register'
TestCase = require '../testcase.coffee'

threeRows = [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
]

t = new TestCase threeRows
t.sendKeys '>'
t.expect threeRows
t.sendKeys 'j>'
t.expect threeRows
t.sendKeys 'j>'
t.expect threeRows
t.sendKeys '<'
t.expect [
  { line: 'top row', children: [
      'middle row',
      'bottom row',
  ] }
]
t.sendKeys 'u'
t.expect threeRows

t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2jx'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'jx'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'nother row'
]
t.sendKeys '>>'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row',
      'nother row'
    ] },
  ] },
]
t.sendKeys 'uu'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'nother row'
]
t.sendKey 'ctrl+r'
t.sendKey 'ctrl+r'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row',
      'nother row'
    ] },
  ] },
]
t.sendKeys 'k'
t.sendKey 'shift+tab'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKey 'shift+tab'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'k'
t.sendKey 'shift+tab'
t.expect [
  'top row',
  { line: 'middle row', children: [
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKey 'ctrl+l'
t.expect [
  { line: 'top row', children: [
    { line: 'middle row', children: [
      { line : 'ottom row', children : [
        'nother row'
      ] },
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  'top row',
  { line: 'middle row', children: [
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'j'
t.sendKey 'ctrl+h'
t.expect [
  { line: 'top row', children: [
    'middle row'
  ] },
  { line : 'ottom row', children : [
    'nother row'
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]

# test block indent
t = new TestCase [
  { line: 'a', children: [
    { line : 'ab', children : [
        'abc'
    ] },
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
]
t.sendKeys 'j'
t.sendKey '<'
t.expect [
  { line : 'a', children : [
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
  { line: 'ab', children: [
    'abc',
  ] },
]
t.sendKey '>'
t.expect [
  { line: 'a', children: [
    { line : 'ad', children : [
      'ade'
    ] },
    { line: 'ab', children: [
      'abc',
    ] },
  ] }
]
t.sendKeys 'u'
t.expect [
  { line : 'a', children : [
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
  { line: 'ab', children: [
    'abc',
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'a', children: [
    { line : 'ab', children : [
        'abc'
    ] },
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
]

# indent uncollapses
t = new TestCase [
  { line: '1', collapsed: true, children: [
    '2'
  ] },
  '3'
]
t.sendKeys 'G>'
t.expect [
  { line: '1', children: [
    '2'
    '3'
  ] },
]

t = new TestCase [
  { line: '1', collapsed: true, children: [
    '2'
  ] },
  { line: '3', children: [
    '4'
  ] },
]
t.sendKeys 'j'
t.sendKey 'ctrl+l'
t.expect [
  { line: '1', children: [
    '2'
    { line: '3', children: [
      '4'
    ] },
  ] },
]

# test regular tab
t = new TestCase [
  '0',
  { line: '1', children: [
    '2'
  ] },
]
t.sendKeys 'j'
t.sendKey 'tab'
t.expect [
  { line: '0', children: [
    '1'
    '2'
  ] },
]

