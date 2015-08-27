require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test go to end and go to beginning
new TestCase ['always to front'], (t) ->
  t.sendKeys '$Gx'
  t.expect ['lways to front']

new TestCase ['a', 'ab', 'abc'], (t) ->
  t.sendKeys '$Gx'
  t.expect ['a', 'ab', 'bc']

new TestCase [
  'ab'
  { text: 'bc', children: [
    'cd'
  ] },
], (t) ->
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

new TestCase [
  'ab'
  { text: 'bc', collapsed: true, children: [
    'cd'
  ] },
], (t) ->
  t.sendKeys 'Gx'
  t.expect [
    'ab'
    { text: 'c', collapsed: true, children: [
      'cd'
    ] },
  ]

new TestCase ['always to front'], (t) ->
  t.sendKeys '$ggx'
  t.expect ['lways to front']

new TestCase ['a', 'ab', 'abc'], (t) ->
  t.sendKeys 'jj$x'
  t.expect ['a', 'ab', 'ab']
  t.sendKeys 'ggx'
  t.expect ['', 'ab', 'ab']

# with zoom
new TestCase [
  'ab'
  { text: 'bc', children: [
    'dc'
    'cd'
  ] },
  'de'
], (t) ->
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
    { text: 'bc', children: [
      'c'
      'd'
    ] },
    'de'
  ]

# with zoom onto collapsed
new TestCase [
  'ab'
  { text: 'bc', collapsed: true, children: [
    'dc'
    'cd'
  ] },
  'de'
], (t) ->
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
    { text: 'bc', collapsed: true, children: [
      'c'
      'd'
    ] },
    'de'
  ]
