TestCase = require '../testcase.coffee'

joinKey = 'J'

describe "join", () ->
  it "works in basic case", () ->
    t = new TestCase ['ab', 'cd']
    t.sendKeys joinKey
    t.expect ['ab cd']
    t.sendKeys 'x'
    t.expect ['abcd']

  it "works with delimiter already there", () ->
    t = new TestCase ['ab', ' cd']
    t.sendKeys joinKey
    t.expect ['ab cd']
    t.sendKeys 'x'
    t.expect ['abcd']

  it "works with child", () ->
    t = new TestCase [
      { text: 'ab', children: [
        'cd'
      ] }
    ]
    t.sendKeys joinKey
    t.expect ['ab cd']
    t.sendKeys 'x'
    t.expect ['abcd']

  it "works where second line has child", () ->
    t = new TestCase [
      'ab'
      { text: 'cd', children: [
        'ef'
        'gh'
      ] }
    ]
    t.sendKeys joinKey
    t.expect [
      { text: 'ab cd', children: [
        'ef'
        'gh'
      ] },
    ]
    t.sendKeys 'x'
    t.expect [
      { text: 'abcd', children: [
        'ef'
        'gh'
      ] },
    ]

  it "is undo and redo-able", () ->
    t = new TestCase [
      'ab'
      { text: 'cd', children: [
        'ef'
      ] }
    ]
    t.sendKeys joinKey
    t.expect [
      { text: 'ab cd', children: [
        'ef'
      ] },
    ]
    t.sendKeys 'x'
    t.expect [
      { text: 'abcd', children: [
        'ef'
      ] },
    ]
    t.sendKeys 'uu'
    t.expect [
      'ab'
      { text: 'cd', children: [
        'ef'
      ] },
    ]
    t.sendKey 'ctrl+r'
    t.expect [
      { text: 'ab cd', children: [
        'ef'
      ] },
    ]

  it "works when second row is empty", () ->
    t = new TestCase ['empty', '']
    t.sendKeys 'J'
    t.expect ['empty']
