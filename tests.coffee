require 'coffee-script/register'
assert = require 'assert'

Data = require './assets/js/data.coffee'
Cursor = require './assets/js/cursor.coffee'
View = require './assets/js/view.coffee'
KeyBindings = require './assets/js/keyBindings.coffee'

class TestCase
  constructor: (serialized = ['']) ->
    @data = new Data
    @data.load
      line: ''
      children: serialized

    @view = new View null, @data
    @view.render = -> return
    @view.renderHelper = -> return
    @view.drawRow = -> return
    @view.undrawCursors = -> return
    @keybinder = new KeyBindings null, null, @view

  sendKeys: (keys) ->
    for key in keys
      @sendKey key

  sendKey: (key) ->
    @keybinder.handleKey key

  expect: (expected) ->
    serialized = do @data.serialize
    assert.deepEqual serialized.children, expected

t = new TestCase
t.sendKey 'i'
t.sendKeys 'hello world'
t.sendKey 'esc'
t.expect ['hello world']

t.sendKeys 'xxxsu'
t.expect ['hello wu']

t.sendKey 'esc'
t.sendKeys 'uuuu'
t.expect ['hello world']
t.sendKeys 'u'
t.expect ['']

t.sendKey 'ctrl+r'
t.expect ['hello world']
for i in [1..4]
  t.sendKey 'ctrl+r'
t.expect ['hello wu']

t.sendKeys '0x'
t.expect ['ello wu']

t.sendKeys '$x'
t.expect ['ello w']

# delete on the last character should send the cursor back one
t.sendKeys 'hx'
t.expect ['ellow']

t.sendKeys 'Iy'
t.sendKey 'esc'
t.expect ['yellow']

t.sendKeys 'Ay'
t.sendKey 'esc'
t.expect ['yellowy']

t.sendKeys 'a purple'
t.sendKey 'esc'
t.expect ['yellowy purple']

t = new TestCase ['hello']

t.sendKey '$'
# i + esc moves the cursor back a character
for i in [1..3]
  t.sendKey 'i'
  t.sendKey 'esc'
t.sendKeys 'ra'
t.expect ['hallo']

# a + esc doesn't
for i in [1..3]
  t.sendKey 'a'
  t.sendKey 'esc'
t.sendKeys 'ru'
t.expect ['hullo']

t = new TestCase ['hello world']

# make sure delete and then undo doesn't move the cursor
t.sendKeys '$hhxux'
t.expect ['hello wold']

# delete on last character should work
t.sendKeys '$dl'
t.expect ['hello wol']
# and it should send the cursor back one
t.sendKey 'x'
t.expect ['hello wo']
# replace
t.sendKeys 'ru'
t.expect ['hello wu']
# undo and redo it
t.sendKeys 'u'
t.expect ['hello wo']
t.sendKey 'ctrl+r'
t.expect ['hello wu']
# hitting left should send the cursor back one more
t.sendKey 'left'
t.sendKeys 'x'
t.expect ['hello u']

t.sendKey '0'
t.sendKey 'right'
t.sendKey 'x'
t.expect ['hllo u']

t.sendKeys '$c0ab'
t.sendKey 'esc'
t.expect ['abu']

# does nothing
t.sendKeys 'dycy'
t.expect ['abu']

# test the shit out of b
t = new TestCase ['the quick brown fox   jumped   over the lazy dog']
t.sendKeys '$bx'
t.expect ['the quick brown fox   jumped   over the lazy og']
t.sendKeys 'bx'
t.expect ['the quick brown fox   jumped   over the azy og']
t.sendKeys 'hbx'
t.expect ['the quick brown fox   jumped   over he azy og']
t.sendKeys 'hhbx'
t.expect ['the quick brown fox   jumped   ver he azy og']
t.sendKeys 'bx'
t.expect ['the quick brown fox   umped   ver he azy og']
t.sendKeys 'bdb'
t.expect ['the quick fox   umped   ver he azy og']
t.sendKeys 'u'
t.expect ['the quick brown fox   umped   ver he azy og']
t.sendKey 'ctrl+r'
t.expect ['the quick fox   umped   ver he azy og']
t.sendKeys 'hhhdb'
t.expect ['the ck fox   umped   ver he azy og']
t.sendKeys 'bx'
t.expect ['he ck fox   umped   ver he azy og']
t.sendKeys '5bx'
t.expect ['e ck fox   umped   ver he azy og']
t = new TestCase ['the']
t.sendKeys '0db'
t.expect ['the']

# test the shit out of e
t = new TestCase ['the quick brown fox   jumped   over the lazy dog']
t.sendKeys 'ex'
t.expect ['th quick brown fox   jumped   over the lazy dog']
t.sendKeys 'ex'
t.expect ['th quic brown fox   jumped   over the lazy dog']
t.sendKeys 'lex'
t.expect ['th quic brow fox   jumped   over the lazy dog']
t.sendKeys 'llex'
t.expect ['th quic brow fo   jumped   over the lazy dog']
t.sendKeys 'ex'
t.expect ['th quic brow fo   jumpe   over the lazy dog']
t.sendKeys 'ede'
t.expect ['th quic brow fo   jumpe   ove lazy dog']
t.sendKeys 'u'
t.expect ['th quic brow fo   jumpe   over the lazy dog']
t.sendKey 'ctrl+r'
t.expect ['th quic brow fo   jumpe   ove lazy dog']
t.sendKeys 'lllde'
t.expect ['th quic brow fo   jumpe   ove la dog']
t.sendKeys 'ex'
t.expect ['th quic brow fo   jumpe   ove la do']
t.sendKeys '5ex'
t.expect ['th quic brow fo   jumpe   ove la d']
t = new TestCase ['the']
t.sendKeys '$de'
t.expect ['th']

# test the shit out of w
t = new TestCase ['the quick brown fox   jumped   over the lazy dog']
t.sendKeys 'wx'
t.expect ['the uick brown fox   jumped   over the lazy dog']
t.sendKeys 'lwx'
t.expect ['the uick rown fox   jumped   over the lazy dog']
t.sendKeys 'elwx'
t.expect ['the uick rown ox   jumped   over the lazy dog']
t.sendKeys 'wx'
t.expect ['the uick rown ox   umped   over the lazy dog']
t.sendKeys 'wdw'
t.expect ['the uick rown ox   umped   the lazy dog']
t.sendKeys 'u'
t.expect ['the uick rown ox   umped   over the lazy dog']
t.sendKey 'ctrl+r'
t.expect ['the uick rown ox   umped   the lazy dog']
t.sendKeys 'lldw'
t.expect ['the uick rown ox   umped   thlazy dog']
t.sendKeys 'wx'
t.expect ['the uick rown ox   umped   thlazy og']
t.sendKeys 'wx'
t.expect ['the uick rown ox   umped   thlazy o']
t.sendKeys '5wx'
t.expect ['the uick rown ox   umped   thlazy ']
t = new TestCase ['the']
t.sendKeys '$dw'
t.expect ['th']

# make sure cursor doesn't go before line
t = new TestCase ['blahblah']
t.sendKeys '0d$iab'
t.expect ['ab']

#########
# REPEAT
#########

t = new TestCase ['']
t.sendKeys '....'
t.expect ['']
t.sendKeys 'irainbow'
t.sendKey 'esc'
t.sendKey '.'
t.expect ['rainborainboww']
t.sendKeys 'x...'
t.expect ['rainborain']

t = new TestCase ['the quick brown fox   jumped   over the lazy dog']
t.sendKeys 'dw'
t.expect ['quick brown fox   jumped   over the lazy dog']
t.sendKeys '..'
t.expect ['fox   jumped   over the lazy dog']
t.sendKeys 'u.'
t.expect ['fox   jumped   over the lazy dog']
t.sendKeys 'dy' # nonsense
t.expect ['fox   jumped   over the lazy dog']
t.sendKeys '..'
t.expect ['over the lazy dog']
t.sendKeys 'rxll.w.e.$.'
t.expect ['xvxr xhx lazy dox']
t.sendKeys 'cbxero'
t.sendKey 'esc'
t.expect ['xvxr xhx lazy xerox']
t.sendKeys 'b.'
t.expect ['xvxr xhx xeroxerox']
t.sendKeys '.'
t.expect ['xvxr xhx xerooxerox']

# repeat works on c
t = new TestCase ['vim is great']
t.sendKeys 'ceblah'
t.sendKey 'esc'
t.sendKeys 'w.w.'
t.expect ['blah blah blah']
# t.sendKeys 'uuuw..'
# t.expect ['vim blah blah']

# repeat works on replace
t = new TestCase ['obladi oblada']
t.sendKeys 'eroehl.'
t.expect ['oblado oblado']

#########
# NUMBERS
#########

# numbers works on movement
t = new TestCase ['obladi oblada o lee lee o lah lah']
t.sendKeys '5lx'
t.expect ['oblad oblada o lee lee o lah lah']
t.sendKeys '6wx'
t.expect ['oblad oblada o lee lee o ah lah']
t.sendKeys '7$x'
t.expect ['oblad oblada o lee lee o ah la']
t.sendKeys '5bx'
t.expect ['oblad oblada o ee lee o ah la']
# numbers repeat works on c
t.sendKeys '$5cb'
t.sendKeys 'blah blah blah'
t.sendKey 'esc'
t.expect ['oblad oblada o blah blah blaha']
# numbers repeat works on d
t.sendKeys '03de'
t.expect [' blah blah blaha']
t.sendKeys 'u'
t.expect ['oblad oblada o blah blah blaha']
# number works within movement
t.sendKeys 'd3e'
t.expect [' blah blah blaha']
# and undo does it all at once
t.sendKeys 'u'
t.expect ['oblad oblada o blah blah blaha']
# try cut too
t.sendKeys 'c3eblah'
t.sendKey 'esc'
t.expect ['blah blah blah blaha']

# numbers repeat works on replace
t = new TestCase ['1234123412341234 is my credit card']
t.sendKeys '12r*'
t.expect ['************1234 is my credit card']
t.sendKeys 'l12X'
t.expect ['1234 is my credit card']
# number repeat works with undo
t.sendKeys 'u'
t.expect ['************1234 is my credit card']
t.sendKeys 'u'
t.expect ['1234123412341234 is my credit card']
t.sendKey 'ctrl+r'
t.expect ['************1234 is my credit card']
t.sendKeys 'lX.................................'
t.expect ['1234 is my credit card']
# number repeat works on undo
t.sendKeys '8u'
t.expect ['********1234 is my credit card']
t.sendKeys '6u'
t.expect ['1234123412341234 is my credit card']

# test f, F, t T
t = new TestCase ['Peter Piper picked a peck of pickled peppers']
t.sendKeys 'fprd'
t.expect ['Peter Pider picked a peck of pickled peppers']
t.sendKeys 'fprl'
t.expect ['Peter Pider licked a peck of pickled peppers']
t.sendKeys '5fpx'
t.expect ['Peter Pider licked a peck of pickled pepers']
t.sendKeys 'u'
t.expect ['Peter Pider licked a peck of pickled peppers']
t.sendKeys '5fpx'
t.expect ['Peter Pider licked a peck of pickled pepers']
t.sendKeys '0tPx'
t.expect ['PeterPider licked a peck of pickled pepers']

t = new TestCase ['Peter Piper picked a peck of pickled peppers']
t.sendKeys '$Fpx'
t.expect ['Peter Piper picked a peck of pickled pepers']
t.sendKeys '3FpTpra'
t.expect ['Peter Piper picked a pack of pickled pepers']
t.sendKeys 'TpruFpal'
t.sendKey 'esc'
t.expect ['Peter Piper plucked a pack of pickled pepers']
t.sendKeys '2TPae'
t.sendKey 'esc'
t.expect ['Peeter Piper plucked a pack of pickled pepers']

t = new TestCase ['edge case']
t.sendKeys 'fsx'
t.expect ['edge cae']
t.sendKeys 'fex'
t.expect ['edge ca']
t.sendKeys 'fex'
t.expect ['edge c']

t = new TestCase ['edge case']
t.sendKeys '2tex'
t.expect ['edge cae']
t.sendKeys 'htex'
t.expect ['edge ce']

t = new TestCase ['edge case']
t.sendKeys '$Fdx'
t.expect ['ege case']
t.sendKeys 'Fex'
t.expect ['ge case']
t.sendKeys 'Fex'
t.expect ['e case']

t = new TestCase ['edge case']
t.sendKeys '$2Tex'
t.expect ['ege case']
t.sendKeys 'Tex'
t.expect ['ee case']
t.sendKeys 'hTfx'
t.expect ['e case']

# test delete with f/t
t = new TestCase ['awdf awdf awdf']
t.sendKeys 'd2fa'
t.expect ['wdf']

t = new TestCase ['awdf awdf awdf']
t.sendKeys 'd2ta'
t.expect ['awdf']

t = new TestCase ['awdf awdf awdf']
t.sendKeys '$d2Fa'
t.expect ['awdf f']

t = new TestCase ['awdf awdf awdf']
t.sendKeys '$d2Ta'
t.expect ['awdf af']

# test multiline
t = new TestCase ['']
t.sendKeys 'ione'
t.sendKey 'esc'
t.sendKeys 'otwo'
t.sendKey 'esc'
t.expect ['one', 'two']
# test j and k
t.sendKeys 'kxjlx'
t.expect ['ne', 'to']
# don't go off the edge!
t.sendKeys 'jxkkx'
t.expect ['e', 't']

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
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["bottom row"],
      }
    ]
  }
]

t = new TestCase threeRows
t.sendKeys 'Oo'
t.expect [
  "o",
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["bottom row"],
      },
    ]
  }
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys 'oO'
t.expect [
  {
    line: "top row",
    children: [
      "O",
      {
        line : "middle row",
        children : ["bottom row"],
      },
    ]
  }
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys 'jOo'
t.expect [
  {
    line: "top row",
    children: [
      "o",
      {
        line : "middle row",
        children : ["bottom row"],
      },
    ]
  }
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys 'joO'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["O", "bottom row"],
      },
    ]
  }
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys '2jOo'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["o", "bottom row"],
      },
    ]
  }
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys '2joO'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["bottom row", "O"],
      },
    ]
  }
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect threeRows

t = new TestCase threeRows
t.sendKeys '>'
t.expect threeRows
t.sendKeys 'j>'
t.expect threeRows
t.sendKeys 'j>'
t.expect threeRows
t.sendKeys '<'
t.expect [
  {
    line: "top row",
    children: [
      "middle row",
      "bottom row",
    ]
  }
]
t.sendKeys 'u'
t.expect threeRows

t = new TestCase [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["bottom row"],
      }
    ]
  },
  "another row"
]
t.sendKeys '2jx'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["ottom row"],
      }
    ]
  },
  "another row"
]
t.sendKeys 'jx'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["ottom row"],
      }
    ]
  },
  "nother row"
]
t.sendKeys '>>'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["ottom row", "nother row"],
      }
    ]
  },
]
t.sendKeys 'uu'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["ottom row"],
      }
    ]
  },
  "nother row"
]
t.sendKey 'ctrl+r'
t.sendKey 'ctrl+r'
t.expect [
  {
    line: "top row",
    children: [
      {
        line : "middle row",
        children : ["ottom row", "nother row"],
      }
    ]
  },
]
t.sendKeys 'k<'
t.expect [
  {
    line: "top row",
    children: [
      "middle row",
      {
        line : "ottom row",
        children : ["nother row"],
      }
    ]
  },
]
t.sendKeys '<'
t.expect [
  {
    line: "top row",
    children: [
      "middle row",
      {
        line : "ottom row",
        children : ["nother row"],
      }
    ]
  },
]
t.sendKeys 'k<'
t.expect [
  "top row",
  {
    line: "middle row",
    children: [
      {
        line : "ottom row",
        children : ["nother row"],
      }
    ]
  },
]
t.sendKeys ']'
t.expect [
  {
    line: "top row",
    children: [
      {
        line: "middle row",
        children: [
          {
            line : "ottom row",
            children : ["nother row"],
          }
        ]
      }
    ]
  },
]
t.sendKeys 'u'
t.expect [
  "top row",
  {
    line: "middle row",
    children: [
      {
        line : "ottom row",
        children : ["nother row"],
      }
    ]
  },
]
t.sendKeys 'u'
t.expect [
  {
    line: "top row",
    children: [
      "middle row",
      {
        line : "ottom row",
        children : ["nother row"],
      }
    ]
  },
]
t.sendKeys 'j['
t.expect [
  {
    line: "top row",
    children: [ "middle row", ]
  },
  {
    line : "ottom row",
    children : ["nother row"],
  }
]
t.sendKeys 'u'
t.expect [
  {
    line: "top row",
    children: [
      "middle row",
      {
        line : "ottom row",
        children : ["nother row"],
      }
    ]
  },
]
