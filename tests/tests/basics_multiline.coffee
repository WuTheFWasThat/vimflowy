require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test multiline
t = new TestCase ['']
t.sendKeys 'ione'
t.sendKey 'esc'
t.sendKeys 'otwo'
t.sendKey 'esc'
t.expect ['one', 'two']
# test j and k
t.sendKeys 'kxjx'
t.expect ['on', 'to']
# don't go off the edge!
t.sendKeys 'kkkxjjjx'
t.expect ['o', 'o']

# test that last line stays
t = new TestCase ['unos', 'dos', 'tres', 'quatro']
t.sendKeys '$jjjx'
t.expect ['unos', 'dos', 'tres', 'quatr']

t = new TestCase ['unos', 'dos', 'tres', 'quatro']
t.sendKeys '$A'
t.sendKey 'down'
t.sendKey 'down'
t.sendKey 'down'
t.sendKey 'backspace'
t.expect ['unos', 'dos', 'tres', 'quatr']

# test o and O, edge cases
t = new TestCase ['a', 's', 'd', 'f']
t.sendKeys 'Oo'
t.expect ['o', 'a', 's', 'd', 'f']
t.sendKey 'esc'
t.sendKeys 'u'
t.expect ['a', 's', 'd', 'f']

t = new TestCase ['a', 's', 'd', 'f']
t.sendKeys '5joO'
t.expect ['a', 's', 'd', 'f', 'O']
t.sendKey 'esc'
t.sendKeys 'u'
t.expect ['a', 's', 'd', 'f']

t = new TestCase ['a', 's', 'd', 'f']
t.sendKeys 'oO'
t.expect ['a', 'O', 's', 'd', 'f']
t.sendKey 'esc'
t.sendKeys 'u'
t.expect ['a', 's', 'd', 'f']

t = new TestCase ['a', 's', 'd', 'f']
t.sendKeys '5jOo'
t.expect ['a', 's', 'd', 'o', 'f']
t.sendKey 'esc'
t.sendKeys 'u'
t.expect ['a', 's', 'd', 'f']

threeRows = [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
]

t = new TestCase threeRows
t.sendKeys 'Oo'
t.expect [
  'o',
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys 'oO'
t.expect [
  { text: 'top row', children: [
    'O',
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys 'jOo'
t.expect [
  { text: 'top row', children: [
    'o',
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys 'joO'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'O',
      'bottom row'
    ] },
  ] },
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys '2jOo'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'o',
      'bottom row'
    ] },
  ] },
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys '2joO'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row',
      'O'
    ] },
  ] },
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase [
  { text: 'a', collapsed: true, children: [
    's', 'd'
  ] },
  'f'
]
t.sendKeys 'oo'
t.expect [
  { text: 'a', collapsed: true, children: [
    's', 'd'
  ] },
  'o'
  'f'
]

# test $ behavior
t = new TestCase [
  'a row'
  'another row'
  'a third row'
]
t.sendKeys '$jx'
t.expect [
  'a row'
  'another ro'
  'a third row'
]
t.sendKeys 'd0x'
t.expect [
  'a row'
  ''
  'a third row'
]
# test tricky -1 on empty row case
t.sendKeys 'j$k'
t.sendKeys 'iab'
t.expect [
  'a row'
  'ab'
  'a third row'
]

# test delete behavior
t = new TestCase [
  'a row'
  'another row'
  'a third row'
]
t.sendKeys 'ddjdd'
t.expect [
  'another row'
]
t.sendKeys 'ux'
t.expect [
  'another row'
  ' third row'
]

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys '3jdd'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'x'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
        'ottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2u'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2jdd'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'x'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'ottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2u'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'dd'
t.expect [ 'another row' ]

# automatically creates a new row
t.sendKeys 'dd'
t.expect [ '' ]
t.sendKeys 'u'
t.expect [ 'another row' ]

# brings back everything!
t.sendKeys 'u'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

# test cc
t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'cc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [ 'a row', 'another row' ]
t.sendKeys 'u'
t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

# see that it handles deletion of everything correctly
t = new TestCase [ 'row', 'row', 'row your boat' ]
t.sendKeys '4dd'
t.expect ['']

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
]
t.sendKeys 'cc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [ 'a row' ]
t.sendKeys 'u'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
]

t = new TestCase [
  { text: 'top row', children: [
    'middle row'
    'bottom row'
  ] },
]
t.sendKeys 'jcc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { text: 'top row', children: [
    'a row'
    'bottom row'
  ] },
]
t.sendKey 'u'
t.sendKeys 'jcc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { text: 'top row', children: [
    'middle row'
    'a row'
  ] },
]

# cursor goes back where it was
t = new TestCase [
  'top row',
  'middle row'
  'bottom row'
]
t.sendKeys 'dd'
t.sendKeys 'jj'
t.sendKeys 'ux'
t.expect
t.expect [
  'op row',
  'middle row',
  'bottom row',
]

# cursor goes back where it was after redo and undo again
t = new TestCase [
  'top row',
  'middle row'
  'bottom row'
]
t.sendKeys 'dd'
t.sendKeys 'jj'
t.sendKeys 'u'
t.sendKey 'ctrl+r'
t.sendKeys 'ux'
t.expect
t.expect [
  'op row',
  'middle row',
  'bottom row',
]

# test redo in tricky case
t = new TestCase [ 'a row' ]
t.sendKeys 'cc'
t.sendKeys 'new row'
t.sendKey 'esc'
t.expect [ 'new row' ]
t.sendKeys 'u'
t.sendKey 'ctrl+r'
t.sendKeys 'x'
t.expect [ 'new ro' ]
t.sendKeys 'uu'
t.expect [ 'a row' ]
t.sendKey 'ctrl+r'
t.expect [ 'new row' ]
t.sendKey 'ctrl+r'
t.expect [ 'new ro' ]

# test redo in trickier case
t = new TestCase [ 'a row' ]
t.sendKeys 'cc'
t.sendKeys 'new row'
t.sendKey 'esc'
t.expect [ 'new row' ]
t.sendKeys 'u'
t.sendKey 'ctrl+r'
t.sendKeys 'x'
t.expect [ 'new ro' ]
t.sendKeys 'uu'
t.expect [ 'a row' ]
# to demonstrate we're not relying on getId behavior
t.data.getId = () ->
    id = 0
    while @lines[id]
      id++
    return id+1
t.sendKey 'ctrl+r'
t.expect [ 'new row' ]
t.sendKey 'ctrl+r'
t.expect [ 'new ro' ]

# test redo in another tricky case
t = new TestCase [ 'a row' ]
t.sendKeys 'yyp'
t.expect [
  'a row'
  'a row'
]
t.sendKeys 'u'
t.sendKey 'ctrl+r'
t.sendKeys 'x'
t.expect [
  'a row'
  ' row'
]
t.sendKeys 'uu'
t.expect [ 'a row' ]
t.sendKey 'ctrl+r'
t.expect [
  'a row'
  'a row'
]
t.sendKey 'ctrl+r'
t.expect [
  'a row'
  ' row'
]

# test redo in another trickier case
t = new TestCase [ 'a row' ]
t.sendKeys 'yyp'
t.expect [
  'a row'
  'a row'
]
t.sendKeys 'u'
t.sendKey 'ctrl+r'
t.sendKeys 'x'
t.expect [
  'a row'
  ' row'
]
t.sendKeys 'uu'
t.expect [ 'a row' ]
# to demonstrate we're not relying on getId behavior
t.data.getId = () ->
    id = 0
    while @lines[id]
      id++
    return id+1
t.sendKey 'ctrl+r'
t.expect [
  'a row'
  'a row'
]
t.sendKey 'ctrl+r'
t.expect [
  'a row'
  ' row'
]

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      'bottom row'
    ] }
  ] },
]
t.sendKeys 'jjcc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      'a row'
    ] },
  ] },
]

t = new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      'bottom row'
    ] },
  ] },
]
t.sendKeys 'jj2cc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      'a row'
    ] },
  ] },
]

t = new TestCase [
  { text: 'parent row', children: [
    'child row 1'
    'child row 2'
  ] },
]
t.sendKeys 'j3dd'
t.expect [ 'parent row' ]
t.sendKeys 'u'
t.expect [
  { text: 'parent row', children: [
    'child row 1'
    'child row 2'
  ] },
]

t = new TestCase [
  { text: 'parent row', children: [
    'child row 1'
    { text: 'child row 2', children: [
      'baby 1'
      'baby 2'
      'baby 3'
    ] },
  ] },
]
t.sendKeys '2j2cc' # despite the 2cc, deletes only one, but deletes all the children
t.sendKeys 'deleted'
t.sendKey 'esc'
t.expect [
  { text: 'parent row', children: [
    'child row 1'
    'deleted'
  ] },
]
t.sendKeys 'u'
t.expect [
  { text: 'parent row', children: [
    'child row 1'
    { text: 'child row 2', children: [
      'baby 1'
      'baby 2'
      'baby 3'
    ] },
  ] },
]
