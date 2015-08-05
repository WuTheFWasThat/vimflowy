require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test search
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

# test search
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

# test search canceling
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

# case insensitive!
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

# multi word!
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

