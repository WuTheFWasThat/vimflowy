require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test swapping
t = new TestCase [
  { line: 'move', children: [
    'me'
  ] },
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'move', children: [
    'me'
  ] },
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    { line: 'move', children: [
      'me'
    ] },
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'move', children: [
      'me'
    ] },
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      { line: 'move', children: [
        'me'
      ] },
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      { line: 'move', children: [
        'me'
      ] },
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
      { line: 'move', children: [
        'me'
      ] },
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
  { line: 'move', children: [
    'me'
  ] },
]

t.sendKey 'ctrl+j'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
  { line: 'move', children: [
    'me'
  ] },
]

t.sendKey 'ctrl+k'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  { line: 'move', children: [
    'me'
  ] },
  '...'
]

t.sendKey 'ctrl+k'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      { line: 'move', children: [
        'me'
      ] },
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+k'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      { line: 'move', children: [
        'me'
      ] },
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+k'
t.expect [
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'move', children: [
      'me'
    ] },
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+k'
t.expect [
  'one',
  { line: 'uno', children: [
    { line: 'move', children: [
      'me'
    ] },
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+k'
t.expect [
  'one',
  { line: 'move', children: [
    'me'
  ] },
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+k'
t.expect [
  { line: 'move', children: [
    'me'
  ] },
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]
t.sendKey 'ctrl+k'
t.expect [
  { line: 'move', children: [
    'me'
  ] },
  'one',
  { line: 'uno', children: [
    'two'
    { line: 'dos', children: [
      'three'
      'tres'
    ] },
  ] },
  '...'
]

# test ctrl+h
t = new TestCase [
  { line: '1', children: [
    '2'
    { line: '3', children: [
      '4'
    ] },
    '5'
  ] },
]
t.sendKeys 'jj'
t.sendKey 'ctrl+h'
t.expect [
  { line: '1', children: [
    '2'
    '5'
  ] },
  { line: '3', children: [
    '4'
  ] },
]

# swap past collapsed makes sibling
t = new TestCase [
  'line'
  { line: '1', collapsed: true, children: [
    '2'
  ] },
]
t.sendKey 'ctrl+j'
t.expect [
  { line: '1', collapsed: true, children: [
    '2'
  ] },
  'line'
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

