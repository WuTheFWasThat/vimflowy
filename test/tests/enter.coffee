TestCase = require '../testcase.coffee'
Register = require '../../assets/js/register.coffee'

describe "enter", () ->
  it "works in basic case", () ->
    t = new TestCase ['']
    t.sendKey 'i'
    t.sendKeys 'hello'
    t.sendKey 'enter'
    t.sendKeys 'world'
    t.sendKey 'esc'
    t.expect ['hello', 'world']
    t.sendKey 'u'
    t.expect ['']

  it "works with tabbing", () ->
    t = new TestCase ['']
    t.sendKey 'i'
    t.sendKeys 'hello'
    t.sendKey 'enter'
    t.sendKeys 'world'
    t.sendKey 'tab'
    t.sendKey 'esc'
    t.expect [
      { text: 'hello', children: [
          'world'
      ] }
    ]
    t.sendKey 'u'
    t.expect ['']
    t.sendKey 'ctrl+r'
    t.expect [
      { text: 'hello', children: [
          'world'
      ] }
    ]
    t.sendKeys 'a of'
    t.sendKey 'shift+tab'
    t.sendKeys ' goo'
    t.sendKey 'esc'
    t.expect ['hello', 'world of goo']

  it "does not mess up registers", () ->
    t = new TestCase ['']
    t.setRegister {type: Register.TYPES.CHARS, data: 'unchanged'}
    t.sendKey 'i'
    t.sendKeys 'helloworld'
    for _ in [0...5]
      t.sendKey 'left'
    t.sendKey 'enter'
    t.sendKey 'esc'
    t.expect ['hello', 'world']
    t.expectRegister {type: Register.TYPES.CHARS, data: 'unchanged'}

  it "works at the end of a line", () ->
    t = new TestCase ['']
    t.sendKey 'i'
    t.sendKeys 'hello'
    t.sendKey 'enter'
    t.sendKey 'esc'
    t.expect ['hello', '']
    t.sendKey 'u'
    t.expect ['']

  it "works at the beginning of a line", () ->
    t = new TestCase ['']
    t.sendKey 'i'
    t.sendKey 'enter'
    t.sendKeys 'hello'
    t.sendKey 'esc'
    t.expect ['', 'hello']
    t.sendKey 'u'
    t.expect ['']

  it "works on lines with children", () ->
    t=  new TestCase ['']
    t.sendKey 'i'
    t.sendKeys 'helloworld'
    t.sendKey 'enter'
    t.sendKeys 'of goo'
    t.sendKey 'esc'
    t.sendKey 'tab'
    t.expect [
      { text: 'helloworld', children: [
          'of goo'
      ] }
    ]
    t.sendKey 'up'
    t.sendKey 'I'
    for _ in [0...5]
      t.sendKey 'right'
    t.sendKey 'enter'
    t.sendKey 'esc'
    t.expect [
      'hello',
      { text: 'world', children: [
          'of goo'
      ] }
    ]

  it "preserves identity at the end of a line", () ->
    t = new TestCase [
      { text: 'hey', id: 1 }
      'you'
      { clone: 1 }
    ]
    t.sendKey 'A'
    t.sendKey 'enter'
    t.sendKeys 'i like'
    t.expect [
      { text: 'hey', id: 1 }
      'i like'
      'you'
      { clone: 1 }
    ]

  it "doesnt preserve identity in the middle of a line", () ->
    t = new TestCase [
      { text: 'hey', id: 1 }
      'you'
      { clone: 1 }
    ]
    t.sendKey '$'
    t.sendKey 'i'
    t.sendKey 'enter'
    t.sendKeys 'ya'
    t.expect [
      'he'
      { text: 'yay', id: 1 }
      'you'
      { clone: 1 }
    ]

  it "handles case with children at end of line", () ->
    t = new TestCase [
      { text: 'hey', id: 1, children: [
        'like'
      ]}
      'you'
      { clone: 1 }
    ]
    t.sendKey 'A'
    t.sendKey 'enter'
    t.sendKeys 'i'
    t.expect [
      { text: 'hey', id: 1, children: [
        'i'
        'like'
      ]}
      'you'
      { clone: 1 }
    ]

  it "handles collapsed case at end of line", () ->
    t = new TestCase [
      { text: 'hey', id: 1, collapsed: true, children: [
        'like'
      ]}
      'you'
      { clone: 1 }
    ]
    t.sendKey 'A'
    t.sendKey 'enter'
    t.sendKeys 'i'
    t.expect [
      { text: 'hey', id: 1, collapsed: true, children: [
        'like'
      ]}
      'i'
      'you'
      { clone: 1 }
    ]
