TestCase = require '../testcase.coffee'

describe "search", () ->
  it "works in basic cases", () ->
    t = new TestCase [
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 5
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'blah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 4

  it "can page down through menu results", () ->
    t = new TestCase [
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 5
    t.sendKey 'ctrl+j'
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'blah',
      'searchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 4

    t = new TestCase [
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 5
    t.sendKey 'ctrl+j'
    t.sendKey 'ctrl+j'
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'blah',
      'searchblah',
      'blahsearchblah',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 4

  it "delete works", () ->
    t = new TestCase [
      'blah',
      'blur',
    ]
    t.sendKeys '/blurb'
    t.expectNumMenuResults 0
    t.sendKey 'backspace'
    t.expectNumMenuResults 1
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'blah',
    ]

    t = new TestCase [
      'blah',
      'blur',
    ]
    t.sendKeys '/blurb'
    t.expectNumMenuResults 0
    t.sendKey 'left'
    t.sendKey 'delete'
    t.expectNumMenuResults 1
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'blah',
    ]

  it "can page up through menu results", () ->
    t = new TestCase [
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 5
    t.sendKey 'ctrl+k'
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      'blah'
    ]
    t.sendKeys '/search'
    t.expectNumMenuResults 4

  it "can be canceled", () ->
    t = new TestCase [
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]
    t.sendKeys '/search'
    t.sendKey 'esc'
    t.sendKeys 'dd'
    t.expect [
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] }
      { text: 'blah', children: [
        'search',
      ] }
    ]

  it "is case insensitive", () ->
    t = new TestCase [
      'case',
      'crease',
      'CASE',
    ]
    t.sendKeys '/case'
    t.sendKey 'ctrl+j'
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'case',
      'crease',
    ]

  it "searches independently for words", () ->
    t = new TestCase [
      'broomball',
      'basketball',
      'basket of bread',
    ]
    t.sendKeys '/bread basket'
    t.sendKey 'enter'
    t.sendKeys 'dd'
    t.expect [
      'broomball',
      'basketball',
    ]

  it "moves the cursor to the searched for row", () ->
    t = new TestCase [
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]
    t.sendKeys 'jj]]]'
    t.expectViewRoot 3
    t.sendKeys '/fir'
    t.sendKey 'enter'
    t.expectViewRoot 1
