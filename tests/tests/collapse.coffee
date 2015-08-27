require 'coffee-script/register'
TestCase = require '../testcase.coffee'

new TestCase [
  { text: 'first', children: [
    'second'
  ] },
  'third'
], { name: "test collapsing" }, (t) ->
  t.sendKeys 'z'
  t.expect [
    { text: 'first', collapsed: true, children: [
      'second'
    ] },
    'third'
  ]
  t.sendKeys 'jx'
  t.expect [
    { text: 'first', collapsed: true, children: [
      'second'
    ] },
    'hird'
  ]
  t.sendKeys 'uu'
  t.expect [
    { text: 'first', children: [
      'second'
    ] },
    'third'
  ]
