require 'coffee-script/register'
TestCase = require '../testcase.coffee'
Register = require '../../assets/js/register.coffee'

secondPasteDisabled = true

new TestCase ['px'], { name: "test pasting!" }, (t) ->
  t.sendKeys 'xp'
  t.expect ['xp']
  t.expectRegisterType Register.TYPES.CHARS
  t.sendKeys 'xp'
  t.expect ['xp']

new TestCase ['one fish, two fish, red fish, blue fish'], {}, (t) ->
  t.sendKeys 'dWWhp'
  t.expect ['fish, one two fish, red fish, blue fish']
  # undo doesn't move cursor, and paste still has stuff in register
  t.sendKeys 'up'
  t.expect ['fish, one two fish, red fish, blue fish']

new TestCase ['one fish, two fish, red fish, blue fish'], {}, (t) ->
  t.sendKeys '2dW2Whp'
  t.expect ['two fish, one fish, red fish, blue fish']
  # undo doesn't move cursor, and paste still has stuff in register
  t.sendKeys 'up'
  t.expect ['two fish, one fish, red fish, blue fish']

new TestCase ['one fish, two fish, red fish, blue fish'], {}, (t) ->
  t.sendKeys 'd2W2Whp'
  t.expect ['two fish, one fish, red fish, blue fish']
  # undo doesn't move cursor, and paste still has stuff in register
  t.sendKeys 'u'
  # type hasnt changed
  t.expectRegisterType Register.TYPES.CHARS
  t.sendKeys 'p'
  t.expect ['two fish, one fish, red fish, blue fish']

new TestCase ['word'], { name: "test an edge case" }, (t) ->
  t.sendKeys 'de'
  t.expect ['']
  t.sendKeys 'p'
  t.expect ['word']
  t.sendKeys 'u'
  t.expect ['']
  # repeat still knows what to do
  t.sendKeys '.'
  t.expect ['word']

new TestCase ['one fish, two fish, red fish, blue fish'], { name: "test paste behind" }, (t) ->
  t.sendKeys '$F,d$3bP'
  t.expect ['one fish, two fish, blue fish, red fish']
  # undo doesn't move cursor, and paste still has stuff in register
  t.sendKeys 'uP'
  t.expect ['one fish, two fish, blue fish, red fish']

new TestCase ['word'], { name: "test an edge case" }, (t) ->
  t.sendKeys 'de'
  t.expect ['']
  t.sendKeys 'P'
  t.expect ['word']
  t.sendKeys 'u'
  t.expect ['']

new TestCase ['humpty', 'dumpty'], { name: "test pasting rows!" }, (t) ->
  t.sendKeys 'dd'
  t.expectRegisterType Register.TYPES.ROWS
  t.expect [ 'dumpty' ]
  t.sendKeys 'p'
  if secondPasteDisabled
    t.expectRegisterType Register.TYPES.NONE
  else
    t.expectRegisterType Register.TYPES.SERIALIZED_ROWS
  t.expect [ 'dumpty', 'humpty' ]
  t.sendKeys 'u'
  t.expect ['dumpty']
  t.sendKeys 'u'
  t.expect ['humpty', 'dumpty']
  if not secondPasteDisabled
    t.sendKeys 'p'
    t.expect ['humpty', 'humpty', 'dumpty']

new TestCase ['humpty', 'dumpty'], {}, (t) ->
  t.sendKeys 'jddP'
  t.expect [ 'dumpty', 'humpty' ]
  t.sendKeys 'u'
  t.expect ['humpty']
  t.sendKeys 'u'
  t.expect ['humpty', 'dumpty']

new TestCase [
  { text: 'herpy', children: [
    { text: 'derpy', children: [
      'burpy'
    ] },
  ] },
], {}, (t) ->
  t.sendKeys 'jjddp'
  t.expect [
    { text: 'herpy', children: [
      'derpy',
      'burpy'
    ] },
  ]

  if secondPasteDisabled
    t.sendKeys 'yy'
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

new TestCase ['lol'], { name: "test yank" }, (t) ->
  t.sendKeys 'yllp'
  t.expect ['loll']

new TestCase ['lol'], {}, (t) ->
  t.sendKeys 'y$P'
  t.expect ['lollol']

new TestCase ['lol'], {}, (t) ->
  t.sendKeys '$ybp'
  t.expect ['lollo']
  t.sendKeys 'u'
  t.expect ['lol']
  t.sendKeys 'P'
  t.expect ['lolol']

new TestCase ['haha ... ha ... funny'], {}, (t) ->
  t.sendKeys 'y3wP'
  t.expect ['haha ... ha haha ... ha ... funny']

new TestCase ['haha ... ha ... funny'], {}, (t) ->
  t.sendKeys 'yep'
  t.expect ['hhahaaha ... ha ... funny']
  # cursor ends at last character
  t.sendKeys 'yffp'
  t.expect ['hhahaaaha ... ha ... faha ... ha ... funny']

new TestCase ['hey', 'yo', 'yo', 'yo', 'yo', 'yo'], { name: "test line yank and paste" }, (t) ->
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

new TestCase ['hey', 'yo', 'yo', 'yo', 'yo', 'yo'], { name: "test line yank and paste" }, (t) ->
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

new TestCase [
  { text: 'hey', children: [
    'yo'
  ] }
], {}, (t) ->
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

new TestCase [
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
], { name: "test paste on collapsed" }, (t) ->
  t.sendKeys 'yyp'
  t.expect [
    { text: 'hey', collapsed: true, children: [
      'yo'
    ] }
    { text: 'hey', collapsed: true, children: [
      'yo'
    ] },
  ]

new TestCase [
  { text: 'hey', collapsed: true, children: [
    'yo'
  ] }
], { name: "test paste preserves collapsedness" }, (t) ->
  t.sendKeys 'yyzp'
  t.expect [
    { text: 'hey', children: [
      { text: 'hey', collapsed: true, children: [
        'yo'
      ] },
      'yo'
    ] }
  ]

  if not secondPasteDisabled
    # test second paste
    new TestCase [
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
