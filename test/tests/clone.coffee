require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "cloning tests", () ->
  it "test yc and p", () ->
    t = new TestCase [
      { text: 'one', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'jjj'
    t.sendKeys 'p'
    t.expect [
      { text: 'one', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
        { text: 'one', children: [
          'uno',
        ] }
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]

  it "test editing in clone and original; test movement from original", () ->
    t = new TestCase [
      { text: 'one', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'jjj'
    t.sendKeys 'p'
    t.sendKeys 'gg'
    t.sendKeys 'x'
    t.sendKeys 'jjjj'
    t.sendKeys 'x'
    t.expect [
      { text: 'e', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
        { text: 'e', children: [
          'uno',
        ] }
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]

    # test movement from the clone
    t.sendKeys 'jj'
    t.sendKeys 'x'
    t.expect [
      { text: 'e', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
        { text: 'e', children: [
          'uno',
        ] }
      ] }
      { text: 'acos', children: [
        'tacos',
      ] }
    ]

  it "works with pasting marks", () ->
    t = new TestCase [
      { text: 'line 1', mark: 'mark1' }
      { text: 'line 2', mark: 'mark2', children: [
        'line 2.1'
      ] }
    ]
    t.expectMarks {'mark1': 1, 'mark2': 2}
    t.sendKeys 'yc'
    t.expectMarks {'mark1': 1, 'mark2': 2}
    t.sendKeys 'jj'
    t.sendKeys 'p'
    t.expect [
      { text: 'line 1', mark: 'mark1' }
      { text: 'line 2', mark: 'mark2', children: [
        'line 2.1',
        { text: 'line 1', mark: 'mark1' }
      ] }
    ]
    t.expectMarks {'mark1': 1, 'mark2': 2}
