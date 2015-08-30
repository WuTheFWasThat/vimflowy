require 'coffee-script/register'
TestCase = require '../testcase.coffee'

describe "marks", () ->
  it "works in basic cases", () ->
    t = new TestCase [
      'a line'
      'another line'
    ]
    t.expectMarks {}
    t.sendKeys 'mmarktest'
    t.sendKey 'enter'
    t.expectMarks {'marktest': 1}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      'another line'
    ]

    t.sendKeys 'jmtest2'
    t.sendKey 'enter'
    t.expectMarks {'marktest': 1, 'test2': 2}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      { text: 'another line', mark: 'test2' }
    ]

    # unmark
    t.sendKeys 'km'
    t.sendKey 'enter'
    t.expectMarks {'test2': 2}
    t.expect [
      'a line',
      { text: 'another line', mark: 'test2' }
    ]

    t.sendKeys 'jm'
    t.sendKey 'enter'
    t.expectMarks {}
    t.expect [
      'a line'
      'another line'
    ]

    t.sendKeys 'dd'
    t.expect [
      'a line'
    ]

    # undo works
    t.sendKeys 'uu'
    t.expectMarks {'test2': 2}
    t.expect [
      'a line',
      { text: 'another line', mark: 'test2' }
    ]

    t.sendKeys 'u'
    t.expectMarks {'marktest': 1, 'test2': 2}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      { text: 'another line', mark: 'test2' }
    ]

    t.sendKeys 'u'
    t.expectMarks {'marktest': 1}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      'another line'
    ]

    # redo works
    t.sendKey 'ctrl+r'
    t.expectMarks {'marktest': 1, 'test2': 2}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      { text: 'another line', mark: 'test2' }
    ]

    # backspace and left and right work
    t.sendKeys 'mhallo'
    t.sendKey 'left'
    t.sendKey 'backspace'
    t.sendKey 'enter'
    t.expectMarks {'marktest': 1, 'halo': 2}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      { text: 'another line', mark: 'halo' }
    ]

    # cancel works
    t.sendKeys 'mbye'
    t.sendKey 'esc'
    t.expectMarks {'marktest': 1, 'halo': 2}
    t.expect [
      { text: 'a line', mark: 'marktest' }
      { text: 'another line', mark: 'halo' }
    ]

  it "works with paste", () ->
    t = new TestCase [
      { text: 'line 1', mark: 'mark1' }
      { text: 'line 2', mark: 'mark2' }
    ]
    t.expectMarks {'mark1': 1, 'mark2': 2}
    t.sendKeys 'dd'
    t.expect [
      { text: 'line 2', mark: 'mark2' }
    ]
    t.expectMarks {'mark2': 2}
    t.sendKeys 'p'
    t.expect [
      { text: 'line 2', mark: 'mark2' }
      { text: 'line 1', mark: 'mark1' }
    ]
    t.expectMarks {'mark2': 2, 'mark1': 1}

  it "doesnt mark when the mark exists, from delete", () ->
    t = new TestCase [
      { text: 'line 1', mark: 'mark1' }
      { text: 'line 2', mark: 'mark2' }
    ]
    t.sendKeys 'mmark2'
    t.sendKey 'enter'
    # does nothing due to mark2 being taken
    t.expect [
      { text: 'line 1', mark: 'mark1' }
      { text: 'line 2', mark: 'mark2' }
    ]
    t.expectMarks {'mark1': 1, 'mark2': 2}

    # once line is deleted, we can mark though
    t.sendKeys 'jdd'
    t.expect [
      { text: 'line 1', mark: 'mark1' }
    ]
    t.expectMarks {'mark1': 1}

    t.sendKeys 'mmark2'
    t.sendKey 'enter'
    t.expect [
      { text: 'line 1', mark: 'mark2' }
    ]
    t.expectMarks {'mark2': 1}

    # paste can't reapply the mark
    t.sendKeys 'p'
    t.expect [
      { text: 'line 1', mark: 'mark2' }
      'line 2'
    ]
    t.expectMarks {'mark2': 1}

    t.sendKeys 'kmmark3'
    t.sendKey 'enter'
    t.expect [
      { text: 'line 1', mark: 'mark3' }
      'line 2'
    ]
    t.expectMarks {'mark3': 1}

  it "doesnt mark when the mark exists, from yank", () ->
    t = new TestCase [
      { text: 'line 1', mark: 'mark1' }
    ]

    t.sendKeys 'yy'
    t.sendKeys ['m', 'enter']
    t.expect [
      'line 1'
    ]
    t.expectMarks {}

    t.sendKeys 'u'
    t.expect [
      { text: 'line 1', mark: 'mark1' }
    ]
    t.expectMarks {'mark1': 1}

    # paste can't reapply the mark
    t.sendKeys 'p'
    t.expect [
      { text: 'line 1', mark: 'mark1' }
      'line 1'
    ]
    t.expectMarks {'mark1': 1}

    t.sendKeys 'kmmark2'
    t.sendKey 'enter'
    t.expect [
      { text: 'line 1', mark: 'mark2' }
      'line 1'
    ]
    t.expectMarks {'mark2': 1}

    # paste can now reapply the mark
    t.sendKeys 'p'
    t.expect [
      { text: 'line 1', mark: 'mark2' }
      { text: 'line 1', mark: 'mark1' }
      'line 1'
    ]
    t.expectMarks {'mark2': 1, 'mark1': 3}

  it "can be visited with gm", () ->
    t = new TestCase [
      { text: '@mark2 @mark3', children: [
        'line'
        { text: 'line', mark: 'mark3' }
      ] }
      { text: 'stuff', mark: 'mark2', children: [
        'more stuff'
      ] }
    ]
    t.sendKeys 'gmx'
    t.expectViewRoot 4
    t.expect [
      { text: '@mark2 @mark3', children: [
        'line'
        { text: 'line', mark: 'mark3' }
      ] }
      { text: 'stuff', mark: 'mark2', children: [
        'ore stuff'
      ] }
    ]
    # goes nowhere
    t.sendKeys '$gmx'
    t.expect [
      { text: '@mark2 @mark3', children: [
        'line'
        { text: 'line', mark: 'mark3' }
      ] }
      { text: 'stuff', mark: 'mark2', children: [
        'ore stuf'
      ] }
    ]
    # back to top
    t.sendKeys '{gg'
    t.expectViewRoot 0
    t.expectCursor 1, 0
    t.sendKeys '$gmx'
    t.expectCursor 3, 2
    t.expect [
      { text: '@mark2 @mark3', children: [
        'line'
        { text: 'lin', mark: 'mark3' }
      ] }
      { text: 'stuff', mark: 'mark2', children: [
        'ore stuf'
      ] }
    ]

  it "can be searched for", () ->
    t = new TestCase [
      { text: 'whoo', mark: 'hip' }
      { text: 'yay', mark: 'hooray', children: [
        'hip'
        'hip'
        { text: 'hooray', mark: 'yay' }
      ] }
      { text: 'awesome', mark: 'whoo' }
    ]
    t.sendKeys '`w'
    t.sendKey 'enter'
    t.sendKeys 'x'
    t.expect [
      { text: 'whoo', mark: 'hip' }
      { text: 'yay', mark: 'hooray', children: [
        'hip'
        'hip'
        { text: 'hooray', mark: 'yay' }
      ] }
      { text: 'wesome', mark: 'whoo' }
    ]

    t.sendKeys '`r'
    t.sendKey 'enter'
    t.sendKeys 'x'
    # goes nowhere
    t.expect [
      { text: 'whoo', mark: 'hip' }
      { text: 'yay', mark: 'hooray', children: [
        'hip'
        'hip'
        { text: 'hooray', mark: 'yay' }
      ] }
      { text: 'esome', mark: 'whoo' }
    ]

    t.sendKeys '`ho'
    t.sendKey 'enter'
    t.sendKeys 'x'
    t.expect [
      { text: 'whoo', mark: 'hip' }
      { text: 'yay', mark: 'hooray', children: [
        'ip'
        'hip'
        { text: 'hooray', mark: 'yay' }
      ] }
      { text: 'esome', mark: 'whoo' }
    ]
    t.sendKeys '`hi'
    t.sendKey 'enter'
    t.sendKeys 'x'
    t.expect [
      { text: 'hoo', mark: 'hip' }
      { text: 'yay', mark: 'hooray', children: [
        'ip'
        'hip'
        { text: 'hooray', mark: 'yay' }
      ] }
      { text: 'esome', mark: 'whoo' }
    ]

  it "works with deletion", () ->
    t = new TestCase [
      { text: 'row', mark: 'row', children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            { text: 'grandgrandchild', mark: 'too' }
            { text: 'grandgrandchild', mark: 'deep' }
          ] }
        ] }
      ] }
      'random'
      'random'
    ]
    t.expectMarks {'row': 1, 'too': 4, 'deep': 5}

    t.sendKeys '`t'
    t.expectNumMenuResults 1
    t.sendKey 'esc'

    t.sendKeys 'dd'
    t.expect [ 'random', 'random' ]
    t.expectMarks {}

    t.sendKeys '`t'
    t.expectNumMenuResults 0
    t.sendKey 'esc'

    t.sendKeys 'mrow'
    t.sendKey 'enter'
    t.expectMarks {'row': 6}

    t.sendKeys 'jmtoo'
    t.sendKey 'enter'
    t.expectMarks {'row': 6, 'too': 7}

    # and marks can fail to apply
    t.sendKeys 'p'
    t.expect [
      { text: 'random', mark: 'row' },
      { text: 'random', mark: 'too' },
      { text: 'row', children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            'grandgrandchild'
            { text: 'grandgrandchild', mark: 'deep' }
          ] }
        ] }
      ] }
    ]
    t.expectMarks {'row': 6, 'too': 7, 'deep': 5}

  it "works with deletion and paste of nested stuff", () ->
    t = new TestCase [
      { text: 'row', mark: 'row', children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            { text: 'grandgrandchild', mark: 'too' }
            { text: 'grandgrandchild', mark: 'deep' }
          ] }
        ] }
      ] }
      'random'
    ]
    t.expectMarks {'row': 1, 'too': 4, 'deep': 5}

    t.sendKeys 'dd'
    t.expect [ 'random' ]
    t.expectMarks {}

    t.sendKeys 'p'
    t.expect [
      'random'
      { text: 'row', mark: 'row', children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            { text: 'grandgrandchild', mark: 'too' }
            { text: 'grandgrandchild', mark: 'deep' }
          ] }
        ] }
      ] }
    ]
    t.expectMarks {'row': 1, 'too': 4, 'deep': 5}

    t.sendKeys 'yyu'
    t.expect [ 'random' ]
    t.expectMarks {}

    t.sendKeys 'mtoo'
    t.sendKey 'enter'
    t.expectMarks {'too': 6}

    # and marks can fail to apply
    t.sendKeys 'p'
    t.expect [
      { text: 'random', mark: 'too' },
      { text: 'row', mark: 'row', children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            'grandgrandchild'
            { text: 'grandgrandchild', mark: 'deep' }
          ] }
        ] }
      ] }
    ]
    # new IDs happen since it's the second paste
    t.expectMarks {'row': 7, 'too': 6, 'deep': 11}
