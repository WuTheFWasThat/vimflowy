TestCase = require '../testcase.coffee'

# Test export formats
t = new TestCase [
  { text: 'first', children: [
    'second'
  ] },
  'third'
]
t.expectExport 'text/plain', "- \n  - first\n    - second\n  - third"
t.expectExport 'application/json',
  (JSON.stringify {
    text: '', children: [
      { text: 'first', children: [
        { text: 'second' }
      ] },
      { text: 'third' }
  ]}, null, 2)


# Make sure zoom does not affect export
t = new TestCase [
  { text: 'first', children: [
    'second'
  ] },
  'third'
]
t.sendKey 'down'
t.sendKey 'alt+l'
t.expectExport 'text/plain', "- \n  - first\n    - second\n  - third"
t.expectExport 'application/json',
  (JSON.stringify {
    text: '', children: [
      { text: 'first', children: [
        { text: 'second' }
      ] },
      { text: 'third' }
  ]}, null, 2)
