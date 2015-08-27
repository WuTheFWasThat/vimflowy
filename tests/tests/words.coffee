require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase ['the quick brown fox   jumped   over the lazy dog'], { name: "test the shit out of b" }, (t) ->
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
new TestCase ['the'], { name: "test the shit out of b" }, (t) ->
  t.sendKeys '0db'
  t.expect ['the']

new TestCase ['', 'a word', '', '  ', '', 'the', '', 'words', 'yes', ''], {}, (t) ->
  t.sendKeys 'G$'
  t.sendKeys 'x'
  t.expect ['', 'a word', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'bx'
  t.expect ['', 'a word', '', '  ', '', 'the', '', 'words', 'es', '']
  t.sendKeys 'bx'
  t.expect ['', 'a word', '', '  ', '', 'the', '', 'ords', 'es', '']
  t.sendKeys 'bx'
  t.expect ['', 'a word', '', '  ', '', 'he', '', 'ords', 'es', '']
  t.sendKeys 'bx'
  t.expect ['', 'a ord', '', '  ', '', 'he', '', 'ords', 'es', '']
  t.sendKeys 'bx'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'ords', 'es', '']
  t.sendKeys 'bx'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'ords', 'es', '']
  t.sendKeys 'ib'
  t.expect ['b', ' ord', '', '  ', '', 'he', '', 'ords', 'es', '']

# TODO:
# new TestCase ['', 'the']
# t.sendKeys 'j0db'
# t.expect ['the']

new TestCase ['the quick brown fox   jumped   over the lazy dog'], { name: "test the shit out of e" }, (t) ->
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
new TestCase ['the'], { name: "test the shit out of e" }, (t) ->
  t.sendKeys '$de'
  t.expect ['th']

new TestCase ['', 'a word', '', '  ', '', 'the', '', 'words', 'yes', ''], { name: "test the shit out of e" }, (t) ->
  t.sendKeys 'x'
  t.expect ['', 'a word', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'ex'
  t.expect ['', ' word', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'ex'
  t.expect ['', ' wor', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'ex'
  t.expect ['', ' wor', '', '  ', '', 'th', '', 'words', 'yes', '']
  t.sendKeys 'ex'
  t.expect ['', ' wor', '', '  ', '', 'th', '', 'word', 'yes', '']
  t.sendKeys 'ex'
  t.expect ['', ' wor', '', '  ', '', 'th', '', 'word', 'ye', '']
  t.sendKeys 'ex'
  t.expect ['', ' wor', '', '  ', '', 'th', '', 'word', 'ye', '']
  t.sendKeys 'ie'
  t.expect ['', ' wor', '', '  ', '', 'th', '', 'word', 'ye', 'e']

new TestCase ['the quick brown fox   jumped   over the lazy dog'], { name: "test the shit out of w" }, (t) ->
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

new TestCase ['the'], { name: "test the shit out of w" }, (t) ->
  t.sendKeys 'dw'
  t.expect ['']

new TestCase ['the'], { name: "test the shit out of w" }, (t) ->
  t.sendKeys '$dw'
  t.expect ['th']

new TestCase ['', 'a word', '', '  ', '', 'the', '', 'words', 'yes', ''], { name: "test the shit out of w" }, (t) ->
  t.sendKeys 'x'
  t.expect ['', 'a word', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'wx'
  t.expect ['', ' word', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'wx'
  t.expect ['', ' ord', '', '  ', '', 'the', '', 'words', 'yes', '']
  t.sendKeys 'wx'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'words', 'yes', '']
  t.sendKeys 'wx'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'ords', 'yes', '']
  t.sendKeys 'wx'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'ords', 'es', '']
  t.sendKeys 'wx'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'ords', 'es', '']
  t.sendKeys 'iw'
  t.expect ['', ' ord', '', '  ', '', 'he', '', 'ords', 'es', 'w']

new TestCase ['ah... yes ... it (ahem) was me!'], { name: "test blocks vs. words!" }, (t) ->
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

new TestCase ['ah... yes ... it (ahem) was me!'], { name: "test blocks vs. words!" }, (t) ->
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

new TestCase ['ah... yes ... it (ahem) was me!'], { name: "test blocks vs. words!" }, (t) ->
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

new TestCase ['ah... yes ... it (ahem) was me!'], { name: "test blocks vs. words!" }, (t) ->
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

new TestCase ['ah... yes ... it (ahem) was me!'], { name: "test blocks vs. words!" }, (t) ->
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

new TestCase ['ah... yes ... it (ahem) was me!'], { name: "test blocks vs. words!" }, (t) ->
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

