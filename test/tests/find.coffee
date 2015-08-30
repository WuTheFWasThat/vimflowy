require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "find", () ->
  it "works in basic cases", () ->
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

  it "works backwards in basic cases", () ->
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

  it "works in edge cases", () ->
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

  it "works in edge cases backwards", () ->
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

  it "works with delete", () ->
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
