require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test f, F, t T
new TestCase ['Peter Piper picked a peck of pickled peppers'], (t) ->
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

new TestCase ['Peter Piper picked a peck of pickled peppers'], (t) ->
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

new TestCase ['edge case'], (t) ->
  t.sendKeys 'fsx'
  t.expect ['edge cae']
  t.sendKeys 'fex'
  t.expect ['edge ca']
  t.sendKeys 'fex'
  t.expect ['edge c']

new TestCase ['edge case'], (t) ->
  t.sendKeys '2tex'
  t.expect ['edge cae']
  t.sendKeys 'htex'
  t.expect ['edge ce']

new TestCase ['edge case'], (t) ->
  t.sendKeys '$Fdx'
  t.expect ['ege case']
  t.sendKeys 'Fex'
  t.expect ['ge case']
  t.sendKeys 'Fex'
  t.expect ['e case']

new TestCase ['edge case'], (t) ->
  t.sendKeys '$2Tex'
  t.expect ['ege case']
  t.sendKeys 'Tex'
  t.expect ['ee case']
  t.sendKeys 'hTfx'
  t.expect ['e case']

# test delete with f/t
new TestCase ['awdf awdf awdf'], (t) ->
  t.sendKeys 'd2fa'
  t.expect ['wdf']

new TestCase ['awdf awdf awdf'], (t) ->
  t.sendKeys 'd2ta'
  t.expect ['awdf']

new TestCase ['awdf awdf awdf'], (t) ->
  t.sendKeys '$d2Fa'
  t.expect ['awdf f']

new TestCase ['awdf awdf awdf'], (t) ->
  t.sendKeys '$d2Ta'
  t.expect ['awdf af']
