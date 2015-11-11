TestCase = require '../testcase.coffee'

swapDownKey = 'ctrl+j'
swapUpKey = 'ctrl+k'

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

  it "enforces constraints upon movement", () ->
    t = new TestCase [
      { text: 'Clone', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        'Not a clone'
      ] }
    ]

    t.sendKeys 'ycjjp'
    t.expect [
      { text: 'Clone', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Clone', children: [
          'Clone child'
        ] }
        'Not a clone'
      ] }
    ]

    t.sendKeys 'gg'
    t.sendKey swapDownKey
    t.expect [
      { text: 'Clone', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Clone', children: [
          'Clone child'
        ] }
        'Not a clone'
      ] }
    ]

  it "works with marks in tricky case", () ->
    t = new TestCase [
      { text: 'Marked clone', mark: 'mark', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        'Not a clone'
      ] }
    ]
    t.expectMarks { 'mark': 1 }

    console.log '\nDEBUG STEP 1'
    console.log 'marks under 1', (t.store.getMarks 1)
    console.log 'marks under 3', (t.store.getMarks 3)
    console.log 'all marks', (do t.store.getAllMarks)


    t.sendKeys 'ycjjp'
    t.expect [
      { text: 'Marked clone', mark: 'mark', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Marked clone', mark: 'mark', children: [
          'Clone child'
        ] }
        'Not a clone'
      ] }
    ]

    console.log '\nDEBUG STEP 2'
    console.log 'marks under 1', (t.store.getMarks 1)
    console.log 'marks under 3', (t.store.getMarks 3)
    console.log 'all marks', (do t.store.getAllMarks)


    t.sendKeys 'ggdd'
    t.expect [
      { text: 'Not a clone', children: [
        { text: 'Marked clone', mark: 'mark', children: [
          'Clone child'
        ] }
        'Not a clone'
      ] }
    ]
    t.expectMarks { 'mark': 1 }

    console.log '\nDEBUG STEP 3'
    console.log 'marks under 1', (t.store.getMarks 1)
    console.log 'marks under 3', (t.store.getMarks 3)
    console.log 'all marks', (do t.store.getAllMarks)

    t.sendKeys 'dd'
    t.expect [ "" ]
    console.log '\nDEBUG STEP 4'
    console.log 'marks under 1', (t.store.getMarks 1)
    console.log 'marks under 3', (t.store.getMarks 3)
    console.log 'all marks', (do t.store.getAllMarks)
    t.expectMarks { }

