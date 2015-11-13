TestCase = require '../testcase.coffee'

swapDownKey = 'ctrl+j'
swapUpKey = 'ctrl+k'

describe "cloning", () ->
  it "works in basic case", () ->
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

  it "works editing both clone and original; works with basic movement", () ->
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

  it "works with movement in complex case", () ->
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

  it "prevents cloning to a sibling", () ->
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

  it "prevents cycles", () ->
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

  it "prevents cycles part 2", () ->
    t = new TestCase [
      { text: 'blah', children: [
        'blah'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'jdd'
    t.expect [
      'blah'
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'jjyckP'
    t.expect [
      'blah'
      { text: 'Will be cloned', children: [
        'Will be cloned'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'jjyckp'
    t.expect [
      'blah'
      { text: 'Will be cloned', children: [
        'Will be cloned'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'kp'
    t.expect [
      'blah'
      { text: 'Will be cloned', children: [
        'Will be cloned'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'u'
    t.expect [
      'blah'
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'u'
    t.expect [
      { text: 'blah', children: [
        'blah'
      ] }
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'p'
    t.expect [
      { text: 'blah', children: [
        'blah'
        { text: 'Not a clone', children: [
          { text: 'Will be cloned', children: [
            'Will be cloned'
          ] }
        ] }
      ] }
      { text: 'Not a clone', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]


  it "works with repeat", () ->
    t = new TestCase [
      'one'
      'two'
      { text: 'three', children: [
        'child',
      ] }
    ]
    t.sendKeys '2yc'
    t.sendKeys 'p'
    t.expect [
      'one'
      'two'
      { text: 'three', children: [
        'child',
      ] }
    ]
    t.sendKeys 'jjp'
    t.expect [
      'one'
      'two'
      { text: 'three', children: [
        'one'
        'two'
        'child',
      ] }
    ]

  it "does not add to history when constraints are violated", () ->
     t = new TestCase [
       'blah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]
     t.sendKeys 'x'
     t.expect [
       'lah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]
     t.sendKeys 'jycp'
     t.expect [
       'lah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]
     t.sendKeys 'u'
     t.expect [
       'blah'
       { text: 'Will be cloned', children: [
         'not a clone'
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

    t.sendKeys 'dd'
    t.expect [ "" ]
    t.expectMarks { }

  it "works with marks in tricky case 2", () ->
    t = new TestCase [
      { text: 'parent', children: [
        { text: 'Not a clone', children: [
          { text: 'Marked child', mark: 'mark' }
        ] }
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ]
    t.expectMarks { 'mark': 3 }

    t.sendKeys 'jycGp'
    t.expect [
      { text: 'parent', children: [
        { text: 'Not a clone', children: [
          { text: 'Marked child', mark: 'mark' }
        ] }
        { text: 'blah', children: [
          'blah'
          { text: 'Not a clone', children: [
            { text: 'Marked child', mark: 'mark' }
          ] }
        ] }
      ] }
    ]
    t.expectMarks { 'mark': 3 }

    t.sendKeys 'jj'
    t.sendKeys ['m', 'enter']
    t.expect [
      { text: 'parent', children: [
        { text: 'Not a clone', children: [
          'Marked child'
        ] }
        { text: 'blah', children: [
          'blah'
          { text: 'Not a clone', children: [
            'Marked child'
          ] }
        ] }
      ] }
    ]
    t.expectMarks {}

    t.sendKeys 'ggdd'
    t.expect [
      ''
    ]
    t.expectMarks {}

    t.sendKeys 'u'
    t.expect [
      { text: 'parent', children: [
        { text: 'Not a clone', children: [
          'Marked child'
        ] }
        { text: 'blah', children: [
          'blah'
          { text: 'Not a clone', children: [
            'Marked child'
          ] }
        ] }
      ] }
    ]
    t.expectMarks {}

  it "works with marks in tricky case 3", () ->
    t = new TestCase [
      { text: 'parent', children: [
        { text: 'Not a clone', children: [
          { text: 'Marked child', mark: 'mark' }
        ] }
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ]
    t.expectMarks { 'mark': 3 }

    t.sendKeys 'jycGp'
    t.expect [
      { text: 'parent', children: [
        { text: 'Not a clone', children: [
          { text: 'Marked child', mark: 'mark' }
        ] }
        { text: 'blah', children: [
          'blah'
          { text: 'Not a clone', children: [
            { text: 'Marked child', mark: 'mark' }
          ] }
        ] }
      ] }
    ]
    t.expectMarks { 'mark': 3 }

    t.sendKeys 'jjdd'
    t.expect [
      { text: 'parent', children: [
        'Not a clone'
        { text: 'blah', children: [
          'blah'
          'Not a clone'
        ] }
      ] }
    ]
    t.expectMarks {}

