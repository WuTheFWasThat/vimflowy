TestCase = require '../testcase.coffee'

# Test export formats
t = new TestCase [
  { line: 'first', children: [
    'second'
  ] },
  'third'
]
t.expectExport 'text/plain', "- \n  - first\n    - second\n  - third"
t.expectExport 'application/json',
  (JSON.stringify {
    line: '', children: [
      { line: 'first', children: [
        { line: 'second', children: [] }
      ] },
      { line: 'third', children: [] }
  ]}, null, 2)


# Make sure zoom does not affect export
t = new TestCase [
  { line: 'first', children: [
    'second'
  ] },
  'third'
]
t.sendKey 'down'
t.sendKey 'alt+l'
t.expectExport 'text/plain', "- \n  - first\n    - second\n  - third"
t.expectExport 'application/json',
  (JSON.stringify {
    line: '', children: [
      { line: 'first', children: [
        { line: 'second', children: [] }
      ] },
      { line: 'third', children: [] }
  ]}, null, 2)
