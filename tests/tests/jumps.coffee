require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test ctrl+o and ctrl+i!
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

t.sendKey 'ctrl+o'
t.expectJumpIndex 0
t.expectViewRoot 0
# doesn't go past border
t.sendKey 'ctrl+o'
t.expectJumpIndex 0
t.expectViewRoot 0

t.sendKey 'ctrl+i'
t.expectJumpIndex 1
t.expectViewRoot 1
# doesn't go past border
t.sendKey 'ctrl+i'
t.expectJumpIndex 1
t.expectViewRoot 1

t.sendKey 'ctrl+o'
t.expectViewRoot 0
t.sendKeys 'dd'
t.expect [
  'third'
]
t.sendKey 'ctrl+i' # fails
t.expectViewRoot 0
t.sendKeys 'p'
t.expect [
  'third'
  { text: 'first', children: [
    'second'
  ] },
]
t.sendKey 'ctrl+i' # succeeds
t.expectViewRoot 1
t.sendKeys 'x'
t.expect [
  'third'
  { text: 'first', children: [
    'econd'
  ] },
]

# test more stuff
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

# erases history properly
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

t.sendKey 'ctrl+o'
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

t.sendKey 'ctrl+o'
# skips both thing with no parent, and thing which is same
t.expectViewRoot 3
t.expectJumpIndex 1, 5

t.sendKey 'ctrl+i'
t.expectViewRoot 0
t.expectJumpIndex 2, 5

# can't go forward for same reason
# possibly bad behavior since we've now cut off access to future jump history?
t.sendKey 'ctrl+i'
t.expectViewRoot 0
t.expectJumpIndex 2, 5

# test cursor position
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

t.sendKey 'ctrl+o'
t.expectViewRoot 0
t.sendKey 'ctrl+i'
t.sendKeys 'j'
t.expectCursor 3, 0

t.sendKey 'ctrl+o'
t.expectViewRoot 0
t.sendKey 'ctrl+i'
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

t.sendKey 'ctrl+o'
t.expectViewRoot 0
t.sendKey 'ctrl+i'
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

t.sendKey 'ctrl+o'
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

t.sendKey 'ctrl+o'
t.expectViewRoot 1
t.expectCursor 2, 0 # cursor changed since 3 is no longer within view root

t.sendKey 'ctrl+o'
t.expectViewRoot 0
t.expectCursor 1, 0 # last cursor hasn't changed

# verify stuff
t.sendKey 'ctrl+i'
t.expectViewRoot 1
t.expectCursor 2, 0

t.sendKey 'ctrl+i'
t.expectViewRoot 0
t.expectCursor 3, 0

# delete last child of 1
t.sendKeys 'kkdd'
t.expect [
  'first'
  'third'
  'cursor'
]

t.sendKey 'ctrl+i' # fails due to 1 not having children anymore
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

t.sendKey 'ctrl+i' # fails due to 1 not having children anymore
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
t.sendKey 'ctrl+o'
t.expectJumpIndex 4

