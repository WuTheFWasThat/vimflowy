require 'coffee-script/register'
assert = require 'assert'

Data = require './assets/js/data.coffee'
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
    @keybinder.handleKeys keys

  sendKey: (key) ->
    @sendKeys [key]

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

# test that redo doesn't go past latest
t = new TestCase ['thing']
t.sendKey 'x'
t.expect ['hing']
t.sendKeys 'u'
t.expect ['thing']
t.sendKey 'ctrl+r'
t.sendKey 'ctrl+r'
t.sendKey 'ctrl+r'
t.expect ['hing']
t.sendKeys 'u'
t.expect ['thing']

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

# test blocks vs. words!
t = new TestCase ['ah... yes ... it (ahem) was me!']
t.sendKeys 'ex'
t.expect ['a... yes ... it (ahem) was me!']
t.sendKeys 'ex'
t.expect ['a.. yes ... it (ahem) was me!']
t.sendKeys 'ex'
t.expect ['a.. ye ... it (ahem) was me!']
t.sendKeys 'ex'
t.expect ['a.. ye .. it (ahem) was me!']
t.sendKeys 'ex'
t.expect ['a.. ye .. i (ahem) was me!']
t.sendKeys 'ex'
t.expect ['a.. ye .. i ahem) was me!']
t.sendKeys 'ex'
t.expect ['a.. ye .. i ahe) was me!']
t.sendKeys 'ex'
t.expect ['a.. ye .. i ahe) wa me!']
t.sendKeys 'ex'
t.expect ['a.. ye .. i ahe) wa m!']
t.sendKeys 'ex'
t.expect ['a.. ye .. i ahe) wa m']
t.sendKeys 'ex'
t.expect ['a.. ye .. i ahe) wa ']

t = new TestCase ['ah... yes ... it (ahem) was me!']
t.sendKeys 'Ex'
t.expect ['ah.. yes ... it (ahem) was me!']
t.sendKeys 'Ex'
t.expect ['ah.. ye ... it (ahem) was me!']
t.sendKeys 'Ex'
t.expect ['ah.. ye .. it (ahem) was me!']
t.sendKeys 'Ex'
t.expect ['ah.. ye .. i (ahem) was me!']
t.sendKeys 'Ex'
t.expect ['ah.. ye .. i (ahem was me!']
t.sendKeys 'Ex'
t.expect ['ah.. ye .. i (ahem wa me!']
t.sendKeys 'Ex'
t.expect ['ah.. ye .. i (ahem wa me']
t.sendKeys 'Ex'
t.expect ['ah.. ye .. i (ahem wa m']

t = new TestCase ['ah... yes ... it (ahem) was me!']
t.sendKeys 'wx'
t.expect ['ah.. yes ... it (ahem) was me!']
t.sendKeys 'wx'
t.expect ['ah.. es ... it (ahem) was me!']
t.sendKeys 'wx'
t.expect ['ah.. es .. it (ahem) was me!']
t.sendKeys 'wx'
t.expect ['ah.. es .. t (ahem) was me!']
t.sendKeys 'wx'
t.expect ['ah.. es .. t ahem) was me!']
t.sendKeys 'wx'
t.expect ['ah.. es .. t ahem was me!']
t.sendKeys 'wx'
t.expect ['ah.. es .. t ahem as me!']
t.sendKeys 'wx'
t.expect ['ah.. es .. t ahem as e!']
t.sendKeys 'wx'
t.expect ['ah.. es .. t ahem as e']
t.sendKeys 'wx'
t.expect ['ah.. es .. t ahem as ']

t = new TestCase ['ah... yes ... it (ahem) was me!']
t.sendKeys 'Wx'
t.expect ['ah... es ... it (ahem) was me!']
t.sendKeys 'Wx'
t.expect ['ah... es .. it (ahem) was me!']
t.sendKeys 'Wx'
t.expect ['ah... es .. t (ahem) was me!']
t.sendKeys 'Wx'
t.expect ['ah... es .. t ahem) was me!']
t.sendKeys 'Wx'
t.expect ['ah... es .. t ahem) as me!']
t.sendKeys 'Wx'
t.expect ['ah... es .. t ahem) as e!']
t.sendKeys 'Wx'
t.expect ['ah... es .. t ahem) as e']
t.sendKeys 'Wx'
t.expect ['ah... es .. t ahem) as ']

t = new TestCase ['ah... yes ... it (ahem) was me!']
t.sendKeys '$'
t.sendKeys 'bx'
t.expect ['ah... yes ... it (ahem) was e!']
t.sendKeys 'bx'
t.expect ['ah... yes ... it (ahem) as e!']
t.sendKeys 'bx'
t.expect ['ah... yes ... it (ahem as e!']
t.sendKeys 'bx'
t.expect ['ah... yes ... it (hem as e!']
t.sendKeys 'bx'
t.expect ['ah... yes ... it hem as e!']
t.sendKeys 'bx'
t.expect ['ah... yes ... t hem as e!']
t.sendKeys 'bx'
t.expect ['ah... yes .. t hem as e!']
t.sendKeys 'bx'
t.expect ['ah... es .. t hem as e!']
t.sendKeys 'bx'
t.expect ['ah.. es .. t hem as e!']
t.sendKeys 'bx'
t.expect ['h.. es .. t hem as e!']
t.sendKeys 'bx'
t.expect ['.. es .. t hem as e!']

t = new TestCase ['ah... yes ... it (ahem) was me!']
t.sendKeys '$'
t.sendKeys 'Bx'
t.expect ['ah... yes ... it (ahem) was e!']
t.sendKeys 'Bx'
t.expect ['ah... yes ... it (ahem) as e!']
t.sendKeys 'Bx'
t.expect ['ah... yes ... it ahem) as e!']
t.sendKeys 'Bx'
t.expect ['ah... yes ... t ahem) as e!']
t.sendKeys 'Bx'
t.expect ['ah... yes .. t ahem) as e!']
t.sendKeys 'Bx'
t.expect ['ah... es .. t ahem) as e!']
t.sendKeys 'Bx'
t.expect ['h... es .. t ahem) as e!']
t.sendKeys 'Bx'
t.expect ['... es .. t ahem) as e!']

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
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
]

t = new TestCase threeRows
t.sendKeys 'Oo'
t.expect [
  'o',
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    'O',
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    'o',
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row',
      'O'
    ] },
  ] },
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
  { line: 'top row', children: [
      'middle row',
      'bottom row',
  ] }
]
t.sendKeys 'u'
t.expect threeRows

t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2jx'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'jx'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'nother row'
]
t.sendKeys '>>'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row',
      'nother row'
    ] },
  ] },
]
t.sendKeys 'uu'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
  'nother row'
]
t.sendKey 'ctrl+r'
t.sendKey 'ctrl+r'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row',
      'nother row'
    ] },
  ] },
]
t.sendKeys 'k<'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys '<'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'k<'
t.expect [
  'top row',
  { line: 'middle row', children: [
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys ']'
t.expect [
  { line: 'top row', children: [
    { line: 'middle row', children: [
      { line : 'ottom row', children : [
        'nother row'
      ] },
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  'top row',
  { line: 'middle row', children: [
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]
t.sendKeys 'j['
t.expect [
  { line: 'top row', children: [
    'middle row'
  ] },
  { line : 'ottom row', children : [
    'nother row'
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'top row', children: [
    'middle row',
    { line : 'ottom row', children : [
      'nother row'
    ] },
  ] },
]

# test delete behavior
t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys '3jdd'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'x'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
        'ottom row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2u'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2jdd'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys 'x'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottomest row'
    ] },
  ] },
  'another row'
]
t.sendKeys '2u'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
  'another row'
]

# test cc
t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
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
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
      'bottomest row'
    ] },
  ] },
]

t = new TestCase [
  { line: 'top row', children: [
    'middle row'
    'bottom row'
  ] },
]
t.sendKeys 'jcc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { line: 'top row', children: [
    'a row'
    'bottom row'
  ] },
]
t.sendKey 'u'
t.sendKeys 'jcc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { line: 'top row', children: [
    'middle row'
    'a row'
  ] },
]

t = new TestCase [
  { line: 'top row', children: [
    { line: 'middle row', children: [
      'bottom row'
    ] }
  ] },
]
t.sendKeys 'jjcc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { line: 'top row', children: [
    { line: 'middle row', children: [
      'a row'
    ] },
  ] },
]

t = new TestCase [
  { line: 'top row', children: [
    { line: 'middle row', children: [
      'bottom row'
    ] },
  ] },
]
t.sendKeys 'jj2cc'
t.sendKeys 'a row'
t.sendKey 'esc'
t.expect [
  { line: 'top row', children: [
    { line: 'middle row', children: [
      'a row'
    ] },
  ] },
]

t = new TestCase [
  { line: 'parent row', children: [
    'child row 1'
    'child row 2'
  ] },
]
t.sendKeys 'j3dd'
t.expect [ 'parent row' ]
t.sendKeys 'u'
t.expect [
  { line: 'parent row', children: [
    'child row 1'
    'child row 2'
  ] },
]

t = new TestCase [
  { line: 'parent row', children: [
    'child row 1'
    { line: 'child row 2', children: [
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
  { line: 'parent row', children: [
    'child row 1'
    'deleted'
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'parent row', children: [
    'child row 1'
    { line: 'child row 2', children: [
      'baby 1'
      'baby 2'
      'baby 3'
    ] },
  ] },
]

# test block indent
t = new TestCase [
  { line: 'a', children: [
    { line : 'ab', children : [
        'abc'
    ] },
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
]
t.sendKeys 'j['
t.expect [
  'a',
  { line: 'ab', children: [
    'abc',
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
]
t.sendKeys ']'
t.expect [
  { line: 'a', children: [
    { line: 'ab', children: [
      'abc',
      { line : 'ad', children : [
        'ade'
      ] },
    ] },
  ] }
]
t.sendKeys 'u'
t.expect [
  'a',
  { line: 'ab', children: [
    'abc',
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'a', children: [
    { line : 'ab', children : [
      'abc'
    ] },
    { line : 'ad', children : [
      'ade'
    ] },
  ] },
]

# test insert mode enter
t = new TestCase
t.sendKey 'i'
t.sendKeys 'hello'
t.sendKey 'enter'
t.sendKeys 'world'
t.sendKey 'esc'
t.expect ['hello', 'world']
t.sendKey 'u'
t.expect ['']

t = new TestCase
t.sendKey 'i'
t.sendKeys 'hello'
t.sendKey 'enter'
t.sendKeys 'world'
t.sendKey 'tab'
t.sendKey 'esc'
t.expect [
 { line: 'hello', children: [
   'world'
 ] }
]
t.sendKey 'u'
t.expect ['']
t.sendKey 'ctrl+r'
t.expect [
 { line: 'hello', children: [
   'world'
 ] }
]
t.sendKeys 'a of'
t.sendKey 'shift+tab'
t.sendKeys ' goo'
t.sendKey 'esc'
t.expect ['hello', 'world of goo']

# test pasting!
t = new TestCase ['px']
t.sendKeys 'xp'
t.expect ['xp']
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
t.sendKeys 'up'
t.expect ['two fish, one fish, red fish, blue fish']

# test an edge case
t = new TestCase ['word']
t.sendKeys 'de'
t.expect ['']
t.sendKeys 'p'
t.expect ['word']
t.sendKeys 'u'
t.expect ['']

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

# test x on empty row
t = new TestCase ['empty', '']
t.sendKeys 'ru'
t.expect ['umpty', '']
t.sendKeys 'jxk.'
t.expect ['mpty', '']

# test pasting rows!
t = new TestCase ['humpty', 'dumpty']
t.sendKeys 'ddp'
t.expect [ 'dumpty', 'humpty' ]
t.sendKeys 'u'
t.expect ['dumpty']
t.sendKeys 'u'
t.expect ['humpty', 'dumpty']

t = new TestCase ['humpty', 'dumpty']
t.sendKeys 'jddP'
t.expect [ 'dumpty', 'humpty' ]
t.sendKeys 'u'
t.expect ['humpty']
t.sendKeys 'u'
t.expect ['humpty', 'dumpty']

t = new TestCase [
  { line: 'herpy', children: [
    { line: 'derpy', children: [
      'burpy'
    ] },
  ] },
]
t.sendKeys 'jjddp'
t.expect [
  { line: 'herpy', children: [
    'derpy',
    'burpy'
  ] },
]

t.sendKeys 'u'
t.expect [
  { line: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'kp'
t.expect [
  { line: 'herpy', children: [
    'burpy',
    'derpy'
  ] },
]

t.sendKeys 'u'
t.expect [
  { line: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'P'
t.expect [
  'burpy'
  { line: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'u'
t.expect [
  { line: 'herpy', children: [
    'derpy',
  ] },
]
t.sendKeys 'jP'
t.expect [
  { line: 'herpy', children: [
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
  { line: 'hey', children: [
    'yo'
  ] }
]
t.sendKeys 'yyp'
t.expect [
  { line: 'hey', children: [
    { line: 'hey', children: [
      'yo'
    ] },
    'yo'
  ] }
]
t.sendKeys 'p'
t.expect [
  { line: 'hey', children: [
    { line: 'hey', children: [
      { line: 'hey', children: [
        'yo'
      ] },
      'yo'
    ] },
    'yo'
  ] }
]
t.sendKeys 'u'
t.expect [
  { line: 'hey', children: [
    { line: 'hey', children: [
      'yo'
    ] },
    'yo'
  ] }
]
t.sendKey 'ctrl+r'
t.expect [
  { line: 'hey', children: [
    { line: 'hey', children: [
      { line: 'hey', children: [
        'yo'
      ] },
      'yo'
    ] },
    'yo'
  ] }
]

# test backspace
t = new TestCase ['abc']
t.sendKey 'A'
t.sendKey 'backspace'
t.sendKey 'backspace'
t.expect ['a']

t = new TestCase ['abc', 'def']
t.sendKeys 'jli'
t.sendKey 'backspace'
t.expect ['abc', 'ef']
t.sendKey 'backspace'
t.expect ['abcef']
t.sendKey 'backspace'
t.expect ['abef']
t.sendKey 'backspace'
t.expect ['aef']
t.sendKey 'backspace'
t.expect ['ef']
t.sendKey 'backspace'
t.expect ['ef']
t.sendKey 'esc'
t.sendKey 'u'
t.expect ['abc', 'def']

t = new TestCase ['ab', 'cd']
t.sendKeys 'jA'
t.sendKey 'backspace'
t.sendKey 'backspace'
t.expect ['ab', '']
t.sendKey 'backspace'
t.expect ['ab']
t.sendKey 'backspace'
t.expect ['a']

t = new TestCase [
  'ab'
  { line: 'bc', children: [
    'cd'
  ] },
]
t.sendKeys 'j'
t.sendKey 'backspace'
# cannot backspace when there are children
t.expect [
  'ab'
  { line: 'bc', children: [
    'cd'
  ] },
]
