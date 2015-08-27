require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase [
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
], { name: "test search" }, (t) ->
  t.sendKeys '/search'
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

new TestCase [
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
], { name: "test search" }, (t) ->
  t.sendKeys '/search'
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

new TestCase [
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
], {}, (t) ->
  t.sendKeys '/search'
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

new TestCase [
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
], { name: "test search canceling" }, (t) ->
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

new TestCase [
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
], {}, (t) ->
  t.sendKeys '/search'
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
    { text: 'blah', children: [
      # NOTE: a new line is created since it got changed to be the view root
      '',
    ] }
  ]

new TestCase [
  'case',
  'crease',
  'CASE',
], { name: "case insensitive!" }, (t) ->
  t.sendKeys '/case'
  t.sendKey 'ctrl+j'
  t.sendKey 'enter'
  t.sendKeys 'dd'
  t.expect [
    'case',
    'crease',
  ]

new TestCase [
  'broomball',
  'basketball',
  'basket of bread',
], { name: "multi word!" }, (t) ->
  t.sendKeys '/bread basket'
  t.sendKey 'enter'
  t.sendKeys 'dd'
  t.expect [
    'broomball',
    'basketball',
  ]
