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

  it "test cursor movement in complex clones", () ->
    t = new TestCase [
      { text: 'Clone', children: [
          'Clone child'
        ]
      }
      { text: 'Not a clone', children: [
          'Also not a clone and going to be deleted'
        ]
      }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'jjjj'
    t.sendKeys 'p'
    t.sendKeys 'kddk'
    t.expect [
      { text: 'Clone', children: [
        'Clone child',
      ] }
      { text: 'Not a clone', children: [
        { text: 'Clone', children: [
          'Clone child',
        ] }
      ] }
    ]
    t.expectCursor 3, 0
    # test movement
    t.sendKeys 'k'
    t.expectCursor 2, 0
    t.sendKeys 'k'
    t.expectCursor 1, 0
    t.sendKeys 'k'
    t.expectCursor 1, 0

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

  it "deletes marks only on last clone delete", () ->
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
    t.sendKeys 'dd'
    t.expect [
      { text: 'line 1', mark: 'mark1' }
      { text: 'line 2', mark: 'mark2', children: [
        'line 2.1',
      ] }
    ]
    t.expectMarks {'mark1': 1, 'mark2': 2}
    t.sendKeys 'kk'
    t.sendKeys 'dd'
    t.expect [
      { text: 'line 2', mark: 'mark2', children: [
        'line 2.1',
      ] }
    ]
    t.expectMarks {'mark2': 2}

  it "cloning to a sibling is impossible", () ->
    t = new TestCase [
      'one',
      'two',
      'three'
    ]
    t.sendKeys 'yc'
    t.sendKeys 'j'
    t.sendKeys 'p'
    t.expect [
      'one',
      'two',
      'three'
    ]

  it "cloning into a cycle is impossible", () ->
    t = new TestCase [
      { text: 'one', children: [
        'uno',
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'j'
    t.sendKeys 'p'
    t.expect [
      { text: 'one', children: [
        'uno',
      ] }
    ]
