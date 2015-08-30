require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "macros", () ->
  it "basically work", () ->
    t = new TestCase [ 'banananana' ]
    # does nothing since nothing has been recorded
    t.sendKeys '@q'
    t.expect [ 'banananana' ]
    t.sendKeys 'qqxlq'
    t.expect [ 'anananana' ]
    t.sendKeys '4@q'
    t.expect [ 'aaaaa' ]
    t.sendKeys 'u'
    t.expect [ 'anananana' ]
    t.sendKey 'ctrl+r'
    t.expect [ 'aaaaa' ]
    t.sendKeys 'u'
    t.expect [ 'anananana' ]
    t.sendKeys 'l@q'
    t.expect [ 'annanana' ]
    t.sendKeys '3.'
    t.expect [ 'annnn' ]

    t = new TestCase [
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
    ]
    # does nothing since nothing has been recorded
    t.sendKeys 'qmr1lr2jq'
    t.sendKeys '7@m'
    t.expect [
      '12000000'
      '01200000'
      '00120000'
      '00012000'
      '00001200'
      '00000120'
      '00000012'
      '00000002'
    ]
    t.sendKeys 'qmxxq'
    t.expect [
      '12000000'
      '01200000'
      '00120000'
      '00012000'
      '00001200'
      '00000120'
      '00000012'
      '000000'
    ]
    # overrides old macro
    t.sendKeys '@m'
    t.expect [
      '12000000'
      '01200000'
      '00120000'
      '00012000'
      '00001200'
      '00000120'
      '00000012'
      '0000'
    ]
    # should it only do one delete?  (just need to enable save on recorded keystream)
    t.sendKeys '.'
    t.expect [
      '12000000'
      '01200000'
      '00120000'
      '00012000'
      '00001200'
      '00000120'
      '00000012'
      '00'
    ]

  it "work nested", () ->
    # create a checkerboard!
    t = new TestCase [
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
    ]
    # does nothing since nothing has been recorded
    t.sendKeys 'qqr1llq'
    t.expect [
      '10000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
    ]
    t.sendKeys '0'
    t.sendKeys 'qo4@qj0l4@qj0q'
    t.expect [
      '10101010'
      '01010101'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
      '00000000'
    ]
    t.sendKeys '3@o'
    t.expect [
      '10101010'
      '01010101'
      '10101010'
      '01010101'
      '10101010'
      '01010101'
      '10101010'
      '01010101'
    ]
