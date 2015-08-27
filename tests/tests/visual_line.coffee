require 'coffee-script/register'
TestCase = require '../testcase.coffee'
siblingDownKey = 'alt+j'
siblingUpKey = 'alt+k'
easyMotionKey = 'space'

new TestCase [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ], (t) ->
  t.sendKeys 'Vjx'
  t.expect [ 'i', 'am', 'a', 'test', 'case' ]
  t.sendKeys 'u'
  t.expect [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]

new TestCase [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ], (t) ->
  t.sendKeys 'GVkc'
  t.expect [ 'hello', 'world', 'i', 'am', 'a', '']
  t.sendKeys 'confused soul'
  t.expect [ 'hello', 'world', 'i', 'am', 'a', 'confused soul' ]
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]

# test o
new TestCase [ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ], (t) ->
  t.sendKeys 'jjjx'
  t.expect [ 'hello', 'world', 'i', 'm', 'a', 'test', 'case' ]
  t.sendKeys 'Vjjokkd'
  t.expect [ 'hello', 'case' ]
  t.sendKeys 'u'
  t.expect [ 'hello', 'world', 'i', 'm', 'a', 'test', 'case' ]
  t.sendKey 'ctrl+r'
  t.expect [ 'hello', 'case' ]

# test repeat
new TestCase [ '1', '2', '3', '4', '5', '6', '7' ], (t) ->
  t.sendKeys 'Vjjx'
  t.expect [ '4', '5', '6', '7' ]
  t.sendKeys '.'
  t.expect [ '7' ]

# yank doesn't save
new TestCase [ '1', '2' ], (t) ->
  t.sendKeys 'xjVy'
  t.expect [ '', '2' ]
  t.sendKeys '.' # this is the x, not the y
  t.expect [ '', '' ]

# test children
new TestCase [
  { text: 'nest', children: [
    'egg'
  ] }
  { text: 'nest 2', children: [
    'egg 2'
  ] }
  { text: 'nest 3', children: [
    'egg 3'
  ] }
], (t) ->
  t.sendKeys ['V', siblingDownKey, 'x']
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
  t.sendKeys ['V', siblingDownKey, siblingDownKey, 'd', 'p']
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
new TestCase [
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
], (t) ->
  # does nothing when can't indent
  t.sendKeys ['j', 'V', '>']
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
  t.sendKeys ['j', 'V', siblingDownKey, '>']
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

# test cursor as ancestor of anchor, and vice versa
new TestCase [
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
], (t) ->
  t.sendKeys 'Vjd'
  t.expect [
    { text: 'nest 2', children: [
      'egg 2'
      'egg 2 2'
    ] }
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ]
  t.sendKeys 'jVkd'
  t.expect [
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ]

# test new LCA behavior
new TestCase [
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
], (t) ->
  t.sendKeys 'jVjd'
  t.expect [
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ]

new TestCase [
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
], (t) ->
  t.sendKeys 'jVjjd'
  t.expect [
    { text: 'nest 3', children: [
      'egg 3'
    ] }
  ]

new TestCase [
  { text: 'this case', children: [
    { text: 'broke in ', children: [
      'real'
      'life'
    ] }
    'whoops!'
  ] }
], (t) ->
  t.sendKeys 'jjjVkkd'
  t.expect [
    { text: 'this case', children: [
      'whoops!'
    ] }
  ]

# test G to go to end of document
new TestCase [
  'yay'
  { text: 'hip', children: [
    { text: 'hop', children: [
      'hoop'
    ] }
  ] }
  'hooray!'
], (t) ->
  t.sendKeys 'VGd'
  t.expect [ '' ]
  t.sendKeys 'u'
  t.expect [
    'yay'
    { text: 'hip', children: [
      { text: 'hop', children: [
        'hoop'
      ] }
    ] }
    'hooray!'
  ]
