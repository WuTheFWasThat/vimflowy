require 'coffee-script/register'
TestCase = require '../testcase.coffee'
Register = require '../../assets/js/register.coffee'

new TestCase [''], { name: "test insert mode enter" }, (t) ->
  t.sendKey 'i'
  t.sendKeys 'hello'
  t.sendKey 'enter'
  t.sendKeys 'world'
  t.sendKey 'esc'
  t.expect ['hello', 'world']
  t.sendKey 'u'
  t.expect ['']

new TestCase [''], { name: "test insert mode enter" }, (t) ->
  t.sendKey 'i'
  t.sendKeys 'hello'
  t.sendKey 'enter'
  t.sendKeys 'world'
  t.sendKey 'tab'
  t.sendKey 'esc'
  t.expect [
    { text: 'hello', children: [
        'world'
    ] }
  ]
  t.sendKey 'u'
  t.expect ['']
  t.sendKey 'ctrl+r'
  t.expect [
    { text: 'hello', children: [
        'world'
    ] }
  ]
  t.sendKeys 'a of'
  t.sendKey 'shift+tab'
  t.sendKeys ' goo'
  t.sendKey 'esc'
  t.expect ['hello', 'world of goo']

new TestCase [''], { name: "split a line in the middle and test register clobbering" }, (t) ->
  t.setRegister {type: Register.TYPES.CHARS, data: 'unchanged'}
  t.sendKey 'i'
  t.sendKeys 'helloworld'
  t.sendKey 'left'
  t.sendKey 'left'
  t.sendKey 'left'
  t.sendKey 'left'
  t.sendKey 'left'
  t.sendKey 'enter'
  t.sendKey 'esc'
  t.expect ['hello', 'world']
  t.expectRegister {type: Register.TYPES.CHARS, data: 'unchanged'}

new TestCase [''], { name: "enter at the end of a line" }, (t) ->
  t.sendKey 'i'
  t.sendKeys 'hello'
  t.sendKey 'enter'
  t.sendKey 'esc'
  t.expect ['hello', '']
  t.sendKey 'u'
  t.expect ['']

new TestCase [''], { name: "enter at the beginning of a line" }, (t) ->
  t.sendKey 'i'
  t.sendKey 'enter'
  t.sendKeys 'hello'
  t.sendKey 'esc'
  t.expect ['', 'hello']
  t.sendKey 'u'
  t.expect ['']

new TestCase [''], { name: "Split line with children" }, (t) ->
  t.sendKey 'i'
  t.sendKeys 'helloworld'
  t.sendKey 'enter'
  t.sendKeys 'of goo'
  t.sendKey 'esc'
  t.sendKey 'tab'
  t.expect [
    { text: 'helloworld', children: [
        'of goo'
    ] }
  ]
  t.sendKey 'up'
  t.sendKey 'I'
  t.sendKey 'right'
  t.sendKey 'right'
  t.sendKey 'right'
  t.sendKey 'right'
  t.sendKey 'right'
  t.sendKey 'enter'
  t.sendKey 'esc'
  t.expect [
    'hello',
    { text: 'world', children: [
        'of goo'
    ] }
  ]
