TestCase = require '../testcase.coffee'

describe "go visible end/beginning", () ->
  it "take you to the first column", () ->
    t = new TestCase ['always to front']
    t.sendKeys '$Gx'
    t.expect ['lways to front']

    t = new TestCase ['a', 'ab', 'abc']
    t.sendKeys '$Gx'
    t.expect ['a', 'ab', 'bc']

    t = new TestCase ['always to front']
    t.sendKeys '$ggx'
    t.expect ['lways to front']

  it "basically works, at root", () ->
    t = new TestCase [
      'ab'
      { text: 'bc', children: [
        'cd'
      ] },
    ]
    t.sendKeys 'Gx'
    t.expect [
      'ab'
      { text: 'bc', children: [
        'd'
      ] },
    ]
    t.sendKeys 'ggx'
    t.expect [
      'b'
      { text: 'bc', children: [
        'd'
      ] },
    ]

    t = new TestCase ['a', 'ab', 'abc']
    t.sendKeys 'jj$x'
    t.expect ['a', 'ab', 'ab']
    t.sendKeys 'ggx'
    t.expect ['', 'ab', 'ab']

  it "ignores collapsed children", () ->
    t = new TestCase [
      'ab'
      { text: 'bc', collapsed: true, children: [
        'cd'
      ] },
    ]
    t.sendKeys 'Gx'
    t.expect [
      'ab'
      { text: 'c', collapsed: true, children: [
        'cd'
      ] },
    ]

  it "works zoomed in", () ->
    t = new TestCase [
      'ab'
      { text: 'bc', children: [
        'dc'
        'cd'
      ] },
      'de'
    ]
    t.sendKeys 'j]Gx'
    t.expect [
      'ab'
      { text: 'bc', children: [
        'dc'
        'd'
      ] },
      'de'
    ]
    t.sendKeys 'ggx'
    t.expect [
      'ab'
      { text: 'c', children: [
        'dc'
        'd'
      ] },
      'de'
    ]

  it "works zoomed in to collapsed", () ->
    t = new TestCase [
      'ab'
      { text: 'bc', collapsed: true, children: [
        'dc'
        'cd'
      ] },
      'de'
    ]
    t.sendKeys 'j]Gx'
    t.expect [
      'ab'
      { text: 'bc', collapsed: true, children: [
        'dc'
        'd'
      ] },
      'de'
    ]
    t.sendKeys 'ggx'
    t.expect [
      'ab'
      { text: 'c', collapsed: true, children: [
        'dc'
        'd'
      ] },
      'de'
    ]
    t.sendKeys 'j]Gx'
    t.expect [
      'ab'
      { text: 'c', collapsed: true, children: [
        'c'
        'd'
      ] },
      'de'
    ]
    t.sendKeys 'ggx'
    t.expect [
      'ab'
      { text: 'c', collapsed: true, children: [
        ''
        'd'
      ] },
      'de'
    ]
