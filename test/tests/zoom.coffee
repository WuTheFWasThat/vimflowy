require 'coffee-script/register'
TestCase = require '../testcase.coffee'

zoomInKey = ']'
zoomOutKey = '['
zoomInAllKey = 'enter'
zoomOutAllKey = 'shift+enter'

describe "zoom", () ->
  it "works in basic cases", () ->
    t = new TestCase [
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]
    t.sendKey zoomInKey
    t.expect [
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]
    t.sendKeys 'jjx'
    t.expect [
      { text: 'first', children: [
        'econd'
      ] },
      'third'
    ]
    # zoom out stays on same line
    t.sendKey zoomOutKey
    t.sendKeys 'x'
    t.expect [
      { text: 'first', children: [
        'cond'
      ] },
      'third'
    ]
    t.sendKeys 'jx'
    t.expect [
      { text: 'first', children: [
        'cond'
      ] },
      'hird'
    ]

  it "works on collapsed, without affecting collapsedness", () ->
    t = new TestCase [
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]
    t.sendKeys 'zjx'
    t.expect [
      { text: 'irst', collapsed: true, children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]
    t.sendKey zoomInKey
    t.sendKeys 'x'
    t.expect [
      { text: 'irst', collapsed: true, children: [
        { text: 'econd', children: [
          'third'
        ] },
      ] },
    ]
    # but now zoom out moves the cursor, since otherwise it's hidden
    t.sendKey zoomOutKey
    t.sendKeys 'x'
    t.expect [
      { text: 'rst', collapsed: true, children: [
        { text: 'econd', children: [
          'third'
        ] },
      ] },
    ]

  it "zooms all the way in", () ->
    t = new TestCase [
      { text: 'first', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'fourth'
          ] },
        ] },
      ] },
    ]
    t.sendKeys 'jjj'
    t.sendKey zoomInAllKey
    t.sendKeys 'x'
    t.expect [
      { text: 'first', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'ourth'
          ] },
        ] },
      ] },
    ]

  it "preserves -1 column", () ->
    t = new TestCase [
      { text: 'first', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'fourth'
          ] },
        ] },
      ] },
    ]
    t.sendKeys '$x$' # second dollar needed, since x ruins it
    t.expect [
      { text: 'firs', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'fourth'
          ] },
        ] },
      ] },
    ]
    # keeps the fact that column is last line!
    t.sendKeys 'jj'
    t.sendKey zoomInAllKey
    t.sendKeys 'x'
    t.expect [
      { text: 'firs', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'fourt'
          ] },
        ] },
      ] },
    ]
    # keeps cursor on fourth row
    t.sendKey zoomOutAllKey
    t.sendKeys 'x'
    t.expect [
      { text: 'firs', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'four'
          ] },
        ] },
      ] },
    ]
    t.sendKeys 'gg$x' # but we can go back up now
    t.expect [
      { text: 'fir', children: [
        { text: 'second', children: [
          { text: 'third', children: [
            'four'
          ] },
        ] },
      ] },
    ]

  it "doesnt allow unindenting out", () ->
    t = new TestCase [
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]
    t.sendKeys 'jj'
    t.sendKey 'shift+tab'
    t.expect [
      { text: 'first', children: [
        'second'
        'third'
      ] },
    ]
    t.sendKey 'u'
    t.expect [
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]
    t.sendKey zoomInAllKey
    t.sendKey 'shift+tab'
    t.expect [
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]

