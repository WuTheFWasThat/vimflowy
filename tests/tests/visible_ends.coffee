require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase ['always to front'], { name: "test go to end and go to beginning" }, (t) ->
  t.sendKeys '$Gx'
  t.expect ['lways to front']

new TestCase ['a', 'ab', 'abc'], { name: "test go to end and go to beginning" }, (t) ->
  t.sendKeys '$Gx'
  t.expect ['a', 'ab', 'bc']

new TestCase [
  'ab'
  { text: 'bc', children: [
    'cd'
  ] },
], {}, (t) ->
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
], {}, (t) ->
  t.sendKeys 'Gx'
  t.expect [
    'ab'
    { text: 'c', collapsed: true, children: [
      'cd'
    ] },
  ]

new TestCase ['always to front'], {}, (t) ->
  t.sendKeys '$ggx'
  t.expect ['lways to front']

new TestCase ['a', 'ab', 'abc'], {}, (t) ->
  t.sendKeys 'jj$x'
  t.expect ['a', 'ab', 'ab']
  t.sendKeys 'ggx'
  t.expect ['', 'ab', 'ab']

new TestCase [
  'ab'
  { text: 'bc', children: [
    'dc'
    'cd'
  ] },
  'de'
], { name: "with zoom" }, (t) ->
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

new TestCase [
  'ab'
  { text: 'bc', collapsed: true, children: [
    'dc'
    'cd'
  ] },
  'de'
], { name: "with zoom onto collapsed" }, (t) ->
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
