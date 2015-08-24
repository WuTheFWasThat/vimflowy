TestCase = require '../testcase.coffee'

# test yc and p ( can't yet handle siblings )
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

# test editing in clone and original
# test and movement from original
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
