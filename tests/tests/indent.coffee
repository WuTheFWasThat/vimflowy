require 'coffee-script/register'
TestCase = require '../testcase.coffee'

indentBlockKey = 'tab'
unindentBlockKey = 'shift+tab'
indentRowKey = '>'
unindentRowKey = '<'

threeRows = [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
]

t = new TestCase threeRows
t.sendKey indentBlockKey
t.expect threeRows
t.sendKeys 'j'
t.sendKey indentBlockKey
t.expect threeRows
t.sendKeys 'j'
t.sendKey indentBlockKey
t.expect threeRows
t.sendKey unindentBlockKey
t.expect [
  { text: 'top row', children: [
      'middle row',
      'bottom row',
  ] }
]
t.sendKeys 'u'
t.expect threeRows

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2jx'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'jx'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'nother row'
]
t.sendKey indentBlockKey
t.sendKey indentBlockKey
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'ottom row',
      'nother row'
    ] },
  ] },
]
t.sendKeys 'uu'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'nother row'
]
t.sendKey 'ctrl+r'
t.sendKey 'ctrl+r'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'ottom row',
      'nother row'
    ] },
  ] },
]
t.sendKeys 'k'
t.sendKey unindentRowKey
t.expect [
  { text: 'top row', children: [
    'middle row',
    { text: 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKey unindentRowKey
t.expect [
  { text: 'top row', children: [
    'middle row',
    { text: 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'k'
t.sendKey unindentRowKey
t.expect [
  'top row',
  { text: 'middle row', children: [
    { text: 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKey 'ctrl+l'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      { text: 'ottom row', children : [
        'nother row'
      ] },
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  'top row',
  { text: 'middle row', children: [
    { text: 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  { text: 'top row', children: [
    'middle row',
    { text: 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'j'
t.sendKey 'ctrl+h'
t.expect [
  { text: 'top row', children: [
    'middle row'
  ] },
  { text: 'ottom row', children : [
    'nother row'
  ] },
]
t.sendKeys 'u'
t.expect [
  { text: 'top row', children: [
    'middle row',
    { text: 'ottom row', children : [
      'nother row'
    ] },
  ] },
]

# test block indent
t = new TestCase [
  { text: 'a', children: [
    { text: 'ab', children : [
        'abc'
    ] },
    { text: 'ad', children : [
      'ade'
    ] },
  ] },
]
t.sendKeys 'j'
t.sendKey unindentBlockKey
t.expect [
  { text: 'a', children : [
    { text: 'ad', children : [
      'ade'
    ] },
  ] },
  { text: 'ab', children: [
    'abc',
  ] },
]
t.sendKey indentBlockKey
t.expect [
  { text: 'a', children: [
    { text: 'ad', children : [
      'ade'
    ] },
    { text: 'ab', children: [
      'abc',
    ] },
  ] }
]
t.sendKeys 'u'
t.expect [
  { text: 'a', children : [
    { text: 'ad', children : [
      'ade'
    ] },
  ] },
  { text: 'ab', children: [
    'abc',
  ] },
]
t.sendKeys 'u'
t.expect [
  { text: 'a', children: [
    { text: 'ab', children : [
        'abc'
    ] },
    { text: 'ad', children : [
      'ade'
    ] },
  ] },
]

# indent uncollapses
t = new TestCase [
  { text: '1', collapsed: true, children: [
    '2'
  ] },
  '3'
]
t.sendKeys 'G'
t.sendKey indentBlockKey
t.expect [
  { text: '1', children: [
    '2'
    '3'
  ] },
]

t = new TestCase [
  { text: '1', collapsed: true, children: [
    '2'
  ] },
  { text: '3', children: [
    '4'
  ] },
]
t.sendKeys 'j'
t.sendKey 'ctrl+l'
t.expect [
  { text: '1', children: [
    '2'
    { text: '3', children: [
      '4'
    ] },
  ] },
]

# test indenting row
t = new TestCase [
  '0',
  { text: '1', children: [
    '2'
  ] },
]
t.sendKeys 'j'
t.sendKey indentRowKey
t.expect [
  { text: '0', children: [
    '1'
    '2'
  ] },
]

# test multi indent block
t = new TestCase [
  { text: 'mama', children: [
    { text: 'oldest kid', children : [
      'grandkid'
    ] },
    'middle kid'
    'young kid'
  ] },
]
t.sendKeys 'jjj2'
t.sendKey indentBlockKey
t.expect [
  { text: 'mama', children: [
    { text: 'oldest kid', children : [
      'grandkid'
      'middle kid'
      'young kid'
    ] },
  ] },
]

# a bit trickier
t = new TestCase [
  { text: 'mama', children: [
    { text: 'oldest kid', collapsed: true, children : [
      'grandkid'
    ] },
    { text: 'middle kid', children : [
      'grandkid 2'
    ] },
    'young kid'
  ] },
]
t.sendKeys 'jj2'
t.sendKey indentBlockKey
t.expect [
  { text: 'mama', children: [
    { text: 'oldest kid', children : [
      'grandkid'
      { text: 'middle kid', children : [
        'grandkid 2'
      ] },
      'young kid'
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  { text: 'mama', children: [
    { text: 'oldest kid', collapsed: true, children : [
      'grandkid'
    ] },
    { text: 'middle kid', children : [
      'grandkid 2'
    ] },
    'young kid'
  ] },
]
t.sendKeys 'k2'
t.sendKey unindentBlockKey
t.expect [
  { text: 'mama', children : [
    'young kid'
  ] },
  { text: 'oldest kid', collapsed: true, children : [
    'grandkid'
  ] },
  { text: 'middle kid', children : [
    'grandkid 2'
  ] },
]

# make sure indent row behaves like indent block when collapsed
t = new TestCase [
  { text: 'grandmama', children: [
    { text: 'mama', collapsed: true, children : [
      'me'
    ] },
  ] },
]
t.sendKeys ['j', unindentRowKey]
t.expect [
  'grandmama',
  { text: 'mama', collapsed: true, children : [
    'me'
  ] }
]

t.sendKey indentRowKey
t.expect [
  { text: 'grandmama', children: [
    { text: 'mama', collapsed: true, children : [
      'me'
    ] },
  ] },
]
