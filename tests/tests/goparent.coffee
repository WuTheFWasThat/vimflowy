require 'coffee-script/register'
TestCase = require '../testcase.coffee'

t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
]
t.sendKeys 'Gx'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
]
t.sendKeys 'gpx'
t.expect [
  { line: 'top row', children: [
    { line : 'iddle row', children : [
      'ottom row'
    ] },
  ] },
]
t.sendKeys 'gpx'
t.expect [
  { line: 'op row', children: [
    { line : 'iddle row', children : [
      'ottom row'
    ] },
  ] },
]
# can't go past the root
t.sendKeys 'gpx'
t.expect [
  { line: 'p row', children: [
    { line : 'iddle row', children : [
      'ottom row'
    ] },
  ] },
]

t = new TestCase [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'bottom row'
    ] },
  ] },
]
t.sendKeys ']]x'
t.expect [
  { line: 'top row', children: [
    { line : 'middle row', children : [
      'ottom row'
    ] },
  ] },
]
t.sendKeys 'gpx'
t.expect [
  { line: 'top row', children: [
    { line : 'iddle row', children : [
      'ottom row'
    ] },
  ] },
]
t.sendKeys 'Gx'
t.expect [
  { line: 'top row', children: [
    { line : 'iddle row', children : [
      'ttom row'
    ] },
  ] },
]
t.sendKeys 'ggx' # verify viewroot is now top row
t.expect [
  { line: 'top row', children: [
    { line : 'ddle row', children : [
      'ttom row'
    ] },
  ] },
]
