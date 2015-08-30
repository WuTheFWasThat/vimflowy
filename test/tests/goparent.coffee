require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "go parent", () ->
  it "works", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]
    t.sendKeys 'Gx'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row'
        ] },
      ] },
    ]
    t.sendKeys 'gpx'
    t.expect [
      { text: 'top row', children: [
        { text: 'iddle row', children : [
          'ottom row'
        ] },
      ] },
    ]
    t.sendKeys 'gpx'
    t.expect [
      { text: 'op row', children: [
        { text: 'iddle row', children : [
          'ottom row'
        ] },
      ] },
    ]
    # can't go past the root
    t.sendKeys 'gpx'
    t.expect [
      { text: 'p row', children: [
        { text: 'iddle row', children : [
          'ottom row'
        ] },
      ] },
    ]

  it "causes a zoom out", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]
    t.sendKeys ']]x'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row'
        ] },
      ] },
    ]
    t.sendKeys 'gpx'
    t.expect [
      { text: 'top row', children: [
        { text: 'iddle row', children : [
          'ottom row'
        ] },
      ] },
    ]
    t.sendKeys 'Gx'
    t.expect [
      { text: 'top row', children: [
        { text: 'iddle row', children : [
          'ttom row'
        ] },
      ] },
    ]
    t.sendKeys 'ggx' # verify viewroot is now top row
    t.expect [
      { text: 'top row', children: [
        { text: 'ddle row', children : [
          'ttom row'
        ] },
      ] },
    ]
