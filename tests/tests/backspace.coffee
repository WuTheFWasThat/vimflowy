require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test backspace
new TestCase ['abc'], (t) ->
  t.sendKey 'A'
  t.sendKey 'backspace'
  t.sendKey 'backspace'
  t.expect ['a']

new TestCase ['abc', 'def'], (t) ->
  t.sendKeys 'jli'
  t.sendKey 'backspace'
  t.expect ['abc', 'ef']
  t.sendKey 'backspace'
  t.expect ['abcef']
  t.sendKey 'backspace'
  t.expect ['abef']
  t.sendKey 'backspace'
  t.expect ['aef']
  t.sendKey 'backspace'
  t.expect ['ef']
  t.sendKey 'backspace'
  t.expect ['ef']
  t.sendKey 'esc'
  t.sendKey 'u'
  t.expect ['abc', 'def']

new TestCase ['ab', 'cd'], (t) ->
  t.sendKeys 'jA'
  t.sendKey 'backspace'
  t.sendKey 'backspace'
  t.expect ['ab', '']
  t.sendKey 'backspace'
  t.expect ['ab']
  t.sendKey 'backspace'
  t.expect ['a']

new TestCase [
  { text: 'ab', children: [
    'bc'
  ] },
  { text: 'cd', children: [
    'de'
  ] },
], (t) ->
  t.sendKeys 'jji'
  t.sendKey 'backspace'
  # cannot backspace when there are children
  t.expect [
    { text: 'ab', children: [
      { text: 'bccd', children: [
        'de'
      ] },
    ] },
  ]
  t.sendKey 'backspace'
  t.sendKey 'backspace'
  t.sendKey 'backspace'
  t.expect [
    { text: 'abcd', children: [
      'de'
    ] },
  ]
  t.sendKey 'backspace'
  t.sendKey 'backspace'
  t.sendKey 'backspace'
  t.expect [
    { text: 'cd', children: [
      'de'
    ] },
  ]

new TestCase [
  { text: 'ab', children: [
    'cd'
  ] },
], (t) ->
  t.sendKeys 'ji'
  t.sendKey 'backspace'
  t.expect [
    'abcd'
  ]
  t.sendKey 'esc'
  t.sendKeys 'u'
  t.expect [
    { text: 'ab', children: [
      'cd'
    ] }
  ]
  t.sendKey 'ctrl+r'
  t.expect [
    'abcd'
  ]
  t.sendKey 'x'
  t.expect [
    'acd'
  ]

# test shift+backspace
new TestCase ['ab', 'cd'], (t) ->
  t.sendKeys 'i'
  t.sendKey 'shift+backspace'
  t.expect ['b', 'cd']
  t.sendKey 'shift+backspace'
  t.expect ['', 'cd']
  t.sendKey 'shift+backspace'
  t.expect ['', 'cd']

# test J join
new TestCase ['ab', 'cd'], (t) ->
  t.sendKeys 'J'
  t.expect ['ab cd']
  t.sendKeys 'x'
  t.expect ['abcd']

new TestCase ['ab', ' cd'], (t) ->
  t.sendKeys 'J'
  t.expect ['ab cd']
  t.sendKeys 'x'
  t.expect ['abcd']

new TestCase [
  { text: 'ab', children: [
    'cd'
  ] },
], (t) ->
  t.sendKeys 'J'
  t.expect ['ab cd']
  t.sendKeys 'x'
  t.expect ['abcd']

new TestCase [
  'ab'
  { text: 'cd', children: [
    'ef'
    'gh'
  ] },
], (t) ->
  t.sendKeys 'J'
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
