TestCase = require '../testcase.coffee'

jumpPreviousKey = 'ctrl+o'
jumpNextKey = 'ctrl+i'

describe "jumps", () ->
  it "basically works", () ->
    t = new TestCase [
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]
    t.expectViewRoot 0
    t.expectCursor 1, 0
    t.sendKeys ']'
    t.expectViewRoot 1
    t.expectCursor 2, 0

    t.sendKey jumpPreviousKey
    t.expectJumpIndex 0
    t.expectViewRoot 0
    # doesn't go past border
    t.sendKey jumpPreviousKey
    t.expectJumpIndex 0
    t.expectViewRoot 0

    t.sendKey jumpNextKey
    t.expectJumpIndex 1
    t.expectViewRoot 1
    # doesn't go past border
    t.sendKey jumpNextKey
    t.expectJumpIndex 1
    t.expectViewRoot 1

    t.sendKey jumpPreviousKey
    t.expectViewRoot 0
    t.sendKeys 'dd'
    t.expect [
      'third'
    ]
    t.sendKey jumpNextKey # fails
    t.expectViewRoot 0
    t.sendKeys 'p'
    t.expect [
      'third'
      { text: 'first', children: [
        'second'
      ] },
    ]
    t.sendKey jumpNextKey # succeeds
    t.expectViewRoot 1
    t.sendKeys 'x'
    t.expect [
      'third'
      { text: 'first', children: [
        'econd'
      ] },
    ]

  it "works with marks", () ->
    t = new TestCase [
      { text: 'okay', mark: 'goto', children: [
        'stuff'
      ] },
      'third'
    ]
    t.sendKeys '\'goto'
    t.sendKey 'enter'
    t.expectViewRoot 1
    t.expectCursor 2, 0
    t.expectJumpIndex 1, 2

    # does nothing due to being the same spot
    t.sendKeys '\'goto'
    t.sendKey 'enter'
    t.expectViewRoot 1
    t.expectCursor 2, 0
    t.expectJumpIndex 1, 2

  it "erases history properly", () ->
    t = new TestCase [
      { text: 'first', children: [
        'second'
      ] },
      { text: 'third', children: [
        'fourth'
      ] },
    ]
    t.expectViewRoot 0
    t.expectJumpIndex 0, 1
    t.sendKeys ']'
    t.expectViewRoot 1
    t.expectJumpIndex 1, 2

    t.sendKey jumpPreviousKey
    t.expectViewRoot 0
    t.expectJumpIndex 0, 2

    t.sendKeys 'jj]'
    t.expectViewRoot 3
    t.expectJumpIndex 1, 2

    t.sendKeys '[kk]'
    t.expectViewRoot 1
    t.expectJumpIndex 3, 4

    t.sendKeys '['
    t.expectViewRoot 0
    t.expectJumpIndex 4, 5

    t.sendKeys 'dd'
    t.expect [
      'first'
      { text: 'third', children: [
        'fourth'
      ] },
    ]

    t.sendKey jumpPreviousKey
    # skips both thing with no parent, and thing which is same
    t.expectViewRoot 3
    t.expectJumpIndex 1, 5

    t.sendKey jumpNextKey
    t.expectViewRoot 0
    t.expectJumpIndex 2, 5

    # can't go forward for same reason
    # possibly bad behavior since we've now cut off access to future jump history?
    t.sendKey jumpNextKey
    t.expectViewRoot 0
    t.expectJumpIndex 2, 5

  it "tries to return cursor position", () ->
    t = new TestCase [
      { text: 'first', children: [
        'second'
        'cursor'
      ] },
      'third'
    ]
    t.expectViewRoot 0
    t.expectCursor 1, 0

    t.sendKeys ']'
    t.expectViewRoot 1
    t.expectCursor 2, 0

    t.sendKey jumpPreviousKey
    t.expectViewRoot 0
    t.sendKey jumpNextKey
    t.sendKeys 'j'
    t.expectCursor 3, 0

    t.sendKey jumpPreviousKey
    t.expectViewRoot 0
    t.sendKey jumpNextKey
    t.expectViewRoot 1
    t.expectCursor 3, 0

    # still goes to cursor despite reordering
    t.sendKeys 'ddP'
    t.expect [
      { text: 'first', children: [
        'cursor'
        'second'
      ] },
      'third'
    ]
    t.expectViewRoot 1
    t.expectCursor 3, 0

    t.sendKey jumpPreviousKey
    t.expectViewRoot 0
    t.sendKey jumpNextKey
    t.expectViewRoot 1
    t.expectCursor 3, 0

    t.expectJumpIndex 1
    t.sendKeys '[]' # go back out and in
    t.expectJumpIndex 3

    # doesn't go to cursor anymore
    t.sendKeys 'dd'
    t.expect [
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]
    t.expectViewRoot 1
    t.expectCursor 2, 0

    t.sendKey jumpPreviousKey
    t.sendKeys 'Gp'
    t.expect [
      { text: 'first', children: [
        'second'
      ] },
      'third'
      'cursor'
    ]
    t.expectViewRoot 0
    t.expectCursor 3, 0

    t.sendKey jumpPreviousKey
    t.expectViewRoot 1
    t.expectCursor 2, 0 # cursor changed since 3 is no longer within view root

    t.sendKey jumpPreviousKey
    t.expectViewRoot 0
    t.expectCursor 1, 0 # last cursor hasn't changed

    # verify stuff
    t.sendKey jumpNextKey
    t.expectViewRoot 1
    t.expectCursor 2, 0

    t.sendKey jumpNextKey
    t.expectViewRoot 0
    t.expectCursor 3, 0

    # delete last child of 1
    t.sendKeys 'kkdd'
    t.expect [
      'first'
      'third'
      'cursor'
    ]

    t.sendKey jumpNextKey # fails due to 1 not having children anymore
    t.expectViewRoot 0
    t.expectCursor 1, 0

    t.sendKeys 'ook'
    t.sendKey 'tab'
    t.sendKey 'esc'
    t.expect [
      { text: 'first', children: [
        'ok'
      ] }
      'third'
      'cursor'
    ]

    t.sendKey jumpNextKey # fails due to 1 not having children anymore
    t.expectViewRoot 1
    t.expectCursor 5, 1

    t.expectJumpIndex 3
    t.sendKeys 'u'
    t.expectJumpIndex 4
    t.expect [
      'first'
      'third'
      'cursor'
    ]
    t.expectViewRoot 0
    t.expectCursor 1, 0

    # no valid jumps - either has no child or is not moving
    t.expectJumpIndex 4
    t.sendKey jumpPreviousKey
    t.expectJumpIndex 4
