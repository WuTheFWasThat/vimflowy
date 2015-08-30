require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "collapse", () ->
  it "works in basic case", () ->
    t = new TestCase [
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]
    t.sendKeys 'z'
    t.expect [
      { text: 'first', collapsed: true, children: [
        'second'
      ] },
      'third'
    ]
    t.sendKeys 'jx'
    t.expect [
      { text: 'first', collapsed: true, children: [
        'second'
      ] },
      'hird'
    ]
    t.sendKeys 'uu'
    t.expect [
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]
