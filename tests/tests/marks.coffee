require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test marks
t = new TestCase [
  'a line'
  'another line'
]
t.expectMarks {}
t.sendKeys 'mmarktest'
t.sendKey 'enter'
t.expectMarks {'marktest': 1}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  'another line'
]

t.sendKeys 'jmtest2'
t.sendKey 'enter'
t.expectMarks {'marktest': 1, 'test2': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'test2' }
]

# unmark
t.sendKeys 'km'
t.sendKey 'enter'
t.expectMarks {'test2': 2}
t.expect [
  'a line',
  { line: 'another line', children: [], mark: 'test2' }
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
  { line: 'another line', children: [], mark: 'test2' }
]

t.sendKeys 'u'
t.expectMarks {'marktest': 1, 'test2': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'test2' }
]

t.sendKeys 'u'
t.expectMarks {'marktest': 1}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  'another line'
]

# redo works
t.sendKey 'ctrl+r'
t.expectMarks {'marktest': 1, 'test2': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'test2' }
]

# backspace and left and right work
t.sendKeys 'mhallo'
t.sendKey 'left'
t.sendKey 'backspace'
t.sendKey 'enter'
t.expectMarks {'marktest': 1, 'halo': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'halo' }
]

# cancel works
t.sendKeys 'mbye'
t.sendKey 'esc'
t.expectMarks {'marktest': 1, 'halo': 2}
t.expect [
  { line: 'a line', children: [], mark: 'marktest' }
  { line: 'another line', children: [], mark: 'halo' }
]

# paste reapplies marks
t = new TestCase [
  { line: 'line 1', children: [], mark: 'mark1' }
  { line: 'line 2', children: [], mark: 'mark2' }
]
t.expectMarks {'mark1': 1, 'mark2': 2}
t.sendKeys 'dd'
t.expect [
  { line: 'line 2', children: [], mark: 'mark2' }
]
t.expectMarks {'mark2': 2}
t.sendKeys 'p'
t.expect [
  { line: 'line 2', children: [], mark: 'mark2' }
  { line: 'line 1', children: [], mark: 'mark1' }
]
t.expectMarks {'mark2': 2, 'mark1': 1}

# try to mark again something that's already there
t = new TestCase [
  { line: 'line 1', children: [], mark: 'mark1' }
  { line: 'line 2', children: [], mark: 'mark2' }
]
t.sendKeys 'mmark2'
t.sendKey 'enter'
# does nothing due to mark2 being taken
t.expect [
  { line: 'line 1', children: [], mark: 'mark1' }
  { line: 'line 2', children: [], mark: 'mark2' }
]
t.expectMarks {'mark1': 1, 'mark2': 2}

# once line is deleted, we can mark though
t.sendKeys 'jdd'
t.expect [
  { line: 'line 1', children: [], mark: 'mark1' }
]
t.expectMarks {'mark1': 1}

t.sendKeys 'mmark2'
t.sendKey 'enter'
t.expect [
  { line: 'line 1', children: [], mark: 'mark2' }
]
t.expectMarks {'mark2': 1}

# paste can't reapply the mark
t.sendKeys 'p'
t.expect [
  { line: 'line 1', children: [], mark: 'mark2' }
  'line 2'
]
t.expectMarks {'mark2': 1}

t.sendKeys 'kmmark3'
t.sendKey 'enter'
t.expect [
  { line: 'line 1', children: [], mark: 'mark3' }
  'line 2'
]
t.expectMarks {'mark3': 1}

# paste can now reapply the mark
t.sendKeys 'p'
t.expect [
  { line: 'line 1', children: [], mark: 'mark3' }
  { line: 'line 2', children: [], mark: 'mark2' }
  'line 2'
]
t.expectMarks {'mark3': 1, 'mark2': 3}

# test going to mark under cursor
t = new TestCase [
  { line: '@mark2 @mark3', children: [
    'line'
    { line: 'line', mark: 'mark3', children: [] }
  ] }
  { line: 'stuff', mark: 'mark2', children: [
    'more stuff'
  ] }
]
t.sendKeys 'gmx'
t.expectViewRoot 4
t.expect [
  { line: '@mark2 @mark3', children: [
    'line'
    { line: 'line', mark: 'mark3', children: [] }
  ] }
  { line: 'stuff', mark: 'mark2', children: [
    'ore stuff'
  ] }
]
# goes nowhere
t.sendKeys '$gmx'
t.expect [
  { line: '@mark2 @mark3', children: [
    'line'
    { line: 'line', mark: 'mark3', children: [] }
  ] }
  { line: 'stuff', mark: 'mark2', children: [
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
  { line: '@mark2 @mark3', children: [
    'line'
    { line: 'lin', mark: 'mark3', children: [] }
  ] }
  { line: 'stuff', mark: 'mark2', children: [
    'ore stuf'
  ] }
]
