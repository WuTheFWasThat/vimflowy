require 'coffee-script/register'
TestCase = require '../testcase.coffee'
Register = require '../../assets/js/register.coffee'

# test pasting!
t = new TestCase ['px']
t.sendKeys 'xp'
t.expect ['xp']
t.expectRegisterType Register.TYPES.CHARS
t.sendKeys 'xp'
t.expect ['xp']

t = new TestCase ['one fish, two fish, red fish, blue fish']
t.sendKeys 'dWWhp'
t.expect ['fish, one two fish, red fish, blue fish']
# undo doesn't move cursor, and paste still has stuff in register
t.sendKeys 'up'
t.expect ['fish, one two fish, red fish, blue fish']

t = new TestCase ['one fish, two fish, red fish, blue fish']
t.sendKeys '2dW2Whp'
t.expect ['two fish, one fish, red fish, blue fish']
# undo doesn't move cursor, and paste still has stuff in register
t.sendKeys 'up'
t.expect ['two fish, one fish, red fish, blue fish']

t = new TestCase ['one fish, two fish, red fish, blue fish']
t.sendKeys 'd2W2Whp'
t.expect ['two fish, one fish, red fish, blue fish']
# undo doesn't move cursor, and paste still has stuff in register
t.sendKeys 'u'
# type hasnt changed
t.expectRegisterType Register.TYPES.CHARS
t.sendKeys 'p'
t.expect ['two fish, one fish, red fish, blue fish']

# test an edge case
t = new TestCase ['word']
t.sendKeys 'de'
t.expect ['']
t.sendKeys 'p'
t.expect ['word']
t.sendKeys 'u'
t.expect ['']
# repeat still knows what to do
t.sendKeys '.'
t.expect ['word']

# test paste behind
t = new TestCase ['one fish, two fish, red fish, blue fish']
t.sendKeys '$F,d$3bP'
t.expect ['one fish, two fish, blue fish, red fish']
# undo doesn't move cursor, and paste still has stuff in register
t.sendKeys 'uP'
t.expect ['one fish, two fish, blue fish, red fish']

# test an edge case
t = new TestCase ['word']
t.sendKeys 'de'
t.expect ['']
t.sendKeys 'P'
t.expect ['word']
t.sendKeys 'u'
t.expect ['']

# test pasting rows!
t = new TestCase ['humpty', 'dumpty']
t.sendKeys 'dd'
t.expectRegisterType Register.TYPES.ROWS
t.expect [ 'dumpty' ]
t.sendKeys 'p'
t.expectRegisterType Register.TYPES.SERIALIZED_ROWS
t.expect [ 'dumpty', 'humpty' ]
t.sendKeys 'u'
t.expect ['dumpty']
t.sendKeys 'u'
t.expect ['humpty', 'dumpty']
t.sendKeys 'p'
t.expect ['humpty', 'humpty', 'dumpty']

t = new TestCase ['humpty', 'dumpty']
t.sendKeys 'jddP'
t.expect [ 'dumpty', 'humpty' ]
t.sendKeys 'u'
t.expect ['humpty']
t.sendKeys 'u'
t.expect ['humpty', 'dumpty']

t = new TestCase [
  { text: 'herpy', children: [
    { text: 'derpy', children: [
      'burpy'
    ] },
  ] },
]
t.sendKeys 'jjddp'
t.expect [
  { text: 'herpy', children: [
    'derpy',
    'burpy'
  ] },
]

t.sendKeys 'u'
t.expect [
  { text: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'kp'
t.expect [
  { text: 'herpy', children: [
    'burpy',
    'derpy'
  ] },
]

t.sendKeys 'u'
t.expect [
  { text: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'P'
t.expect [
  'burpy'
  { text: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'u'
t.expect [
  { text: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'jP'
t.expect [
  { text: 'herpy', children: [
    'burpy',
    'derpy',
  ] },
]

# test yank
t = new TestCase ['lol']
t.sendKeys 'yllp'
t.expect ['loll']

t = new TestCase ['lol']
t.sendKeys 'y$P'
t.expect ['lollol']

t = new TestCase ['lol']
t.sendKeys '$ybp'
t.expect ['lollo']
t.sendKeys 'u'
t.expect ['lol']
t.sendKeys 'P'
t.expect ['lolol']

t = new TestCase ['haha ... ha ... funny']
t.sendKeys 'y3wP'
t.expect ['haha ... ha haha ... ha ... funny']

t = new TestCase ['haha ... ha ... funny']
t.sendKeys 'yep'
t.expect ['hhahaaha ... ha ... funny']
# cursor ends at last character
t.sendKeys 'yffp'
t.expect ['hhahaaaha ... ha ... faha ... ha ... funny']

# test line yank and paste
t = new TestCase ['hey', 'yo', 'yo', 'yo', 'yo', 'yo']
t.sendKeys 'yyjp'
t.expect ['hey', 'yo', 'hey', 'yo', 'yo', 'yo', 'yo']
t.sendKeys 'jjP'
t.expect ['hey', 'yo', 'hey', 'yo', 'hey', 'yo', 'yo', 'yo']
# this should only affect one of the pasted lines (verify it's a copy!)
t.sendKeys 'x'
t.expect ['hey', 'yo', 'hey', 'yo', 'ey', 'yo', 'yo', 'yo']
t.sendKeys 'uu'
t.expect ['hey', 'yo', 'hey', 'yo', 'yo', 'yo', 'yo']
t.sendKeys 'u'
t.expect ['hey', 'yo', 'yo', 'yo', 'yo', 'yo']
# the register now contains the 'h' from the 'x'
t.sendKeys 'jjjjjp'
t.expect ['hey', 'yo', 'yo', 'yo', 'yo', 'yho']

t = new TestCase ['hey', 'yo', 'yo', 'yo', 'yo', 'yo']
t.sendKeys 'yyjp'
t.expect ['hey', 'yo', 'hey', 'yo', 'yo', 'yo', 'yo']
t.sendKeys 'jjP'
t.expect ['hey', 'yo', 'hey', 'yo', 'hey', 'yo', 'yo', 'yo']
t.sendKeys 'ry'
t.expect ['hey', 'yo', 'hey', 'yo', 'yey', 'yo', 'yo', 'yo']
t.sendKeys 'uu'
t.expect ['hey', 'yo', 'hey', 'yo', 'yo', 'yo', 'yo']
t.sendKeys 'u'
t.expect ['hey', 'yo', 'yo', 'yo', 'yo', 'yo']
# splice does NOT replace register!
t.sendKeys 'jjjjjp'
t.expect ['hey', 'yo', 'yo', 'yo', 'yo', 'yo', 'hey']

t = new TestCase [
  { text: 'hey', children: [
    'yo'
  ] }
]
t.sendKeys 'yyp'
t.expect [
  { text: 'hey', children: [
    { text: 'hey', children: [
      'yo'
    ] },
    'yo'
  ] }
]
t.sendKeys 'p'
t.expect [
  { text: 'hey', children: [
    { text: 'hey', children: [
      { text: 'hey', children: [
        'yo'
      ] },
      'yo'
    ] },
    'yo'
  ] }
]
t.sendKeys 'u'
t.expect [
  { text: 'hey', children: [
    { text: 'hey', children: [
      'yo'
    ] },
    'yo'
  ] }
]
t.sendKey 'ctrl+r'
t.expect [
  { text: 'hey', children: [
    { text: 'hey', children: [
      { text: 'hey', children: [
        'yo'
      ] },
      'yo'
    ] },
    'yo'
  ] }
]

# test paste on collapsed
t = new TestCase [
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
]
t.sendKeys 'yyp'
t.expect [
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] },
]

# test paste preserves collapsedness
t = new TestCase [
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
]
t.sendKeys 'yyzp'
t.expect [
  { text: 'hey', children: [
    { text: 'hey', collapsed: true, children: [
      'yo'
    ] },
    'yo'
  ] }
]

# test second paste
t = new TestCase [
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
  'me'
  'cool'
]
t.sendKeys 'Vjd'
t.expect [
  'cool'
]
t.expectRegisterType Register.TYPES.ROWS
t.sendKeys 'p'
t.expectRegisterType Register.TYPES.SERIALIZED_ROWS
t.expect [
  'cool'
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
  'me'
]
t.sendKeys 'zryjrh'
t.expect [
  'cool'
  { text: 'yey', children: [
    'ho'
  ] }
  'me'
]
# second paste should be original thing
t.sendKeys 'P'
t.expect [
  'cool'
  { text: 'yey', children: [
    { text: 'hey', collapsed: true, children: [
      'yo'
    ] }
    'me'
    'ho'
  ] }
  'me'
]
