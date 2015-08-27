require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase [''], { name: "test multiline" }, (t) ->
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

new TestCase ['unos', 'dos', 'tres', 'quatro'], { name: "test that last line stays" }, (t) ->
  t.sendKeys '$jjjx'
  t.expect ['unos', 'dos', 'tres', 'quatr']

new TestCase ['unos', 'dos', 'tres', 'quatro'], { name: "test that last line stays" }, (t) ->
  t.sendKeys '$A'
  t.sendKey 'down'
  t.sendKey 'down'
  t.sendKey 'down'
  t.sendKey 'backspace'
  t.expect ['unos', 'dos', 'tres', 'quatr']

# test o and O, edge cases
new TestCase ['a', 's', 'd', 'f'], { name: "test o and O, edge cases" }, (t) ->
  t.sendKeys 'Oo'
  t.expect ['o', 'a', 's', 'd', 'f']
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect ['a', 's', 'd', 'f']

new TestCase ['a', 's', 'd', 'f'], { name: "test o and O, edge cases" }, (t) ->
  t.sendKeys '5joO'
  t.expect ['a', 's', 'd', 'f', 'O']
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect ['a', 's', 'd', 'f']

new TestCase ['a', 's', 'd', 'f'], { name: "test o and O, edge cases" }, (t) ->
  t.sendKeys 'oO'
  t.expect ['a', 'O', 's', 'd', 'f']
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect ['a', 's', 'd', 'f']

new TestCase ['a', 's', 'd', 'f'], { name: "test o and O, edge cases" }, (t) ->
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

new TestCase threeRows, { name: "test o and O, edge cases" }, (t) ->
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

new TestCase threeRows, { name: "test o and O, edge cases" }, (t) ->
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

new TestCase threeRows, { name: "test o and O, edge cases" }, (t) ->
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

new TestCase threeRows, { name: "test o and O, edge cases" }, (t) ->
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

new TestCase threeRows, { name: "test o and O, edge cases" }, (t) ->
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

new TestCase threeRows, { name: "test o and O, edge cases" }, (t) ->
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

new TestCase [
  { text: 'a', collapsed: true, children: [
    's', 'd'
  ] },
  'f'
], {}, (t) ->
  t.sendKeys 'oo'
  t.expect [
    { text: 'a', collapsed: true, children: [
      's', 'd'
    ] },
    'o'
    'f'
  ]

new TestCase [
  'a row'
  'another row'
  'a third row'
], { name: "test $ behavior" }, (t) ->
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

new TestCase [
  'a row'
  'another row'
  'a third row'
], { name: "test delete behavior" }, (t) ->
  t.sendKeys 'ddjdd'
  t.expect [
    'another row'
  ]
  t.sendKeys 'ux'
  t.expect [
    'another row'
    ' third row'
  ]

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
], {}, (t) ->
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

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
], {}, (t) ->
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

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
], {}, (t) ->
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

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
], { name: "test cc" }, (t) ->
  t.sendKeys 'cc'
  t.sendKeys 'a row'
  t.sendKey 'esc'
  t.expect [ 'a row', 'another row' ]
  t.sendKeys 'u'

new TestCase [ 'row', 'row', 'row your boat' ], { name: "see that it handles deletion of everything correctly" }, (t) ->
  t.sendKeys '4dd'
  t.expect ['']

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
], {}, (t) ->
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

new TestCase [
  { text: 'top row', children: [
    'middle row'
    'bottom row'
  ] },
], {}, (t) ->
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

new TestCase [
  'top row',
  'middle row'
  'bottom row'
], { name: "cursor goes back where it was" }, (t) ->
  t.sendKeys 'dd'
  t.sendKeys 'jj'
  t.sendKeys 'ux'
  t.expect
  t.expect [
    'op row',
    'middle row',
    'bottom row',
  ]

new TestCase [
  'top row',
  'middle row'
  'bottom row'
], { name: "cursor goes back where it was after redo and undo again" }, (t) ->
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

new TestCase [ 'a row' ], { name: "test redo in tricky case" }, (t) ->
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

new TestCase [ 'a row' ], { name: "test redo in trickier case" }, (t) ->
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

new TestCase [ 'a row' ], { name: "test redo in another tricky case" }, (t) ->
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

new TestCase [ 'a row' ], { name: "test redo in another trickier case" }, (t) ->
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

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      'bottom row'
    ] }
  ] },
], {}, (t) ->
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

new TestCase [
  { text: 'top row', children: [
    { text: 'middle row', children: [
      'bottom row'
    ] },
  ] },
], {}, (t) ->
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

new TestCase [
  { text: 'parent row', children: [
    'child row 1'
    'child row 2'
  ] },
], {}, (t) ->
  t.sendKeys 'j3dd'
  t.expect [ 'parent row' ]
  t.sendKeys 'u'
  t.expect [
    { text: 'parent row', children: [
      'child row 1'
      'child row 2'
    ] },
  ]

new TestCase [
  { text: 'parent row', children: [
    'child row 1'
    { text: 'child row 2', children: [
      'baby 1'
      'baby 2'
      'baby 3'
    ] },
  ] },
], {}, (t) ->
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
