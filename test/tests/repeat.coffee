TestCase = require '../testcase.coffee'

describe "repeat", () ->

  it "works with insertion of text", () ->
    t = new TestCase ['']
    t.sendKeys '....'
    t.expect ['']
    t.sendKeys 'irainbow'
    t.sendKey 'esc'
    t.sendKey '.'
    t.expect ['rainborainboww']
    t.sendKeys 'x...'
    t.expect ['rainborain']

  it "works with deletion + motion", () ->
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

  it "works with change (c)", () ->
    t = new TestCase ['vim is great']
    t.sendKeys 'ceblah'
    t.sendKey 'esc'
    t.sendKeys 'w.w.'
    t.expect ['blah blah blah']

  it "works with replace", () ->
    t = new TestCase ['obladi oblada']
    t.sendKeys 'eroehl.'
    t.expect ['oblado oblado']


describe "tricky cases for repeat", () ->
  it "test repeating x on empty row", () ->
    t = new TestCase ['empty', '']
    t.sendKeys 'ru'
    t.expect ['umpty', '']
    t.sendKeys 'jxk.'
    t.expect ['mpty', '']

  it "repeat of change", () ->
    t = new TestCase [
      'oh say can you see',
      'and the home of the brave'
    ]
    t.sendKeys 'ceme'
    t.sendKey 'esc'
    t.expect [
      'me say can you see',
      'and the home of the brave'
    ]
    t.sendKeys 'j$b.'
    t.expect [
      'me say can you see',
      'and the home of the me'
    ]

  it "repeat of paste, edge case with empty line", () ->
    t = new TestCase ['word']
    t.sendKeys 'de'
    t.expect ['']
    t.sendKeys 'p'
    t.expect ['word']
    t.sendKeys 'u'
    t.expect ['']
    # repeat still knows what to do
    t.sendKeys '.'
    t.expect ['word']
    t.sendKeys '.'
    t.expect ['wordword']

  it "works with visual mode", () ->
    t = new TestCase [ '1234567' ]
    t.sendKeys 'vllx'
    t.expect [ '4567' ]
    t.sendKeys '.'
    t.expect [ '7' ]

  it "doesnt repeat visual mode yank", () ->
    t = new TestCase [ '1234' ]
    t.sendKeys 'xvly'
    t.expect [ '234' ]
    t.sendKeys '.'
    t.expect [ '24' ]

