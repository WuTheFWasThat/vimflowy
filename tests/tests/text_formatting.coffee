require 'coffee-script/register'
TestCase = require '../testcase.coffee'

boldKey = 'ctrl+B'
italicizeKey = 'ctrl+I'
underlineKey = 'ctrl+U'
strikethroughKey = 'ctrl+enter'
siblingDownKey = 'alt+j'
siblingUpKey = 'alt+k'

new TestCase [''], { name: "test insert mode" }, (t) ->
  t.sendKeys 'i'
  t.sendKey underlineKey
  t.sendKeys 'underline'
  t.sendKey underlineKey
  t.sendKeys ' '
  t.sendKey strikethroughKey
  t.sendKeys 'strikethrough'
  t.sendKey strikethroughKey
  t.sendKey 'esc'
  t.expect [
    {
      text:          'underline strikethrough'
      underline:     '.........              '
      strikethrough: '          .............'
    }
  ]
  t.sendKeys 'u'
  t.expect ['']
  # redo knows the format
  t.sendKey 'ctrl+r'
  t.expect [
    {
      text:          'underline strikethrough'
      underline:     '.........              '
      strikethrough: '          .............'
    }
  ]

new TestCase [''], {}, (t) ->
  t.sendKeys 'i'
  t.sendKeys 'normal, '
  t.sendKey italicizeKey
  t.sendKeys 'italic, '
  t.sendKey boldKey
  t.sendKeys 'bold italic, '
  t.sendKey italicizeKey
  t.sendKeys 'bold'
  t.expect [
    {
      text:   'normal, italic, bold italic, bold'
      bold:   '                .................'
      italic: '        .....................    '
    }
  ]
  t.sendKey 'esc'
  # beginning of line, gets cursor correctly
  t.sendKeys '0iab'
  t.sendKey 'esc'
  t.expect [
    {
      text:   'abnormal, italic, bold italic, bold'
      bold:   '                  .................'
      italic: '          .....................    '
    }
  ]
  t.sendKeys '0cWv'
  t.sendKey 'esc'
  t.expect [
    {
      text:   'vitalic, bold italic, bold'
      bold:   '         .................'
      italic: '......................    '
    }
  ]
  # uses style left of cursor
  t.sendKeys 'Wia'
  t.sendKey 'right'
  t.sendKeys 'r'
  t.sendKey 'esc'
  t.expect [
    {
      text:   'vitalic, abrold italic, bold'
      bold:   '          ..................'
      italic: '........................    '
    }
  ]

  t.sendKeys 'yy'
  # replace preserves style
  t.sendKeys 'flrafora'
  t.sendKey 'esc'
  t.expect [
    {
      text:   'vitalic, abroad italic, bald'
      bold:   '          ..................'
      italic: '........................    '
    }
  ]

  # pastes properly
  t.sendKeys 'p'
  t.expect [
    {
      text:   'vitalic, abroad italic, bald'
      bold:   '          ..................'
      italic: '........................    '
    }
    {
      text:   'vitalic, abrold italic, bold'
      bold:   '          ..................'
      italic: '........................    '
    }
  ]

new TestCase [''], { name: "test going onto next line 'enter' in insert mode" }, (t) ->
  t.sendKeys 'i'
  t.sendKey boldKey
  t.sendKeys 'this'
  t.sendKey 'enter'
  t.sendKeys 'is'
  t.sendKey 'enter'
  t.sendKey italicizeKey
  t.sendKeys 'bold'
  t.expect [
    {
      text:   'this'
      bold:   '....'
    }
    {
      text:   'is'
      bold:   '..'
    }
    {
      text:   'bold'
      bold:   '....'
      italic: '....'
    }
  ]
  t.sendKey 'esc'
  t.sendKeys 'onormal'
  t.expect [
    {
      text:   'this'
      bold:   '....'
    }
    {
      text:   'is'
      bold:   '..'
    }
    {
      text:   'bold'
      bold:   '....'
      italic: '....'
    }
    'normal'
  ]
  t.sendKey 'esc'

new TestCase [
  {
    text:   'bim'
    bold:   '. .'
    italic: ' ..'
  }
], { name: "test xp" }, (t) ->
  t.sendKeys 'xp'
  t.expect [
    {
      text:   'ibm'
      bold:   ' ..'
      italic: '. .'
    }
  ]

new TestCase [
  'test'
], { name: "test normal mode" }, (t) ->
  t.sendKey strikethroughKey
  t.expect [
    {
      text:          'test'
      strikethrough: '....'
    }
  ]
  t.sendKey strikethroughKey
  t.expect [
    'test'
  ]

new TestCase [
  {
    text:   'test'
    bold:   '... '
  }
], {}, (t) ->
  t.sendKeys 'll'
  t.sendKey boldKey
  t.expect [
    {
      text:   'test'
      bold:   '....'
    }
  ]
  t.sendKey boldKey
  t.expect [
    'test'
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text:   'test'
      bold:   '....'
    }
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text:   'test'
      bold:   '... '
    }
  ]
  # cursor ends up where it was
  t.sendKeys 'x'
  t.expect [
    {
      text:   'tet'
      bold:   '.. '
    }
  ]

new TestCase [
  'hello world'
], { name: "visual mode" }, (t) ->
  t.sendKeys 've'
  t.sendKey boldKey
  t.expect [
    {
      text: 'hello world'
      bold: '.....      '
    }
  ]
  t.sendKey 'x'
  t.expect [
    {
      text: 'hell world'
      bold: '....      '
    }
  ]
  t.sendKeys 'v$'
  t.sendKey strikethroughKey
  t.expect [
    {
      text:          'hell world'
      bold:          '....      '
      strikethrough: '    ......'
    }
  ]
  t.sendKeys 'x'
  t.expect [
    {
      text:          'hell worl'
      bold:          '....     '
      strikethrough: '    .....'
    }
  ]
  t.sendKeys 'vb'
  t.sendKey strikethroughKey
  t.expect [
    {
      text:          'hell worl'
      bold:          '....     '
      strikethrough: '    .    '
    }
  ]
  t.sendKeys 'hvb'
  t.sendKey boldKey
  t.expect [
    {
      text:          'hell worl'
      bold:          '.....    '
      strikethrough: '    .    '
    }
  ]
  t.sendKeys 'v'
  t.sendKey boldKey
  t.expect [
    {
      text:          'hell worl'
      bold:          ' ....    '
      strikethrough: '    .    '
    }
  ]
  t.sendKeys 'v$'
  t.sendKey strikethroughKey
  t.expect [
    {
      text:          'hell worl'
      bold:          ' ....    '
      strikethrough: '.........'
    }
  ]
  t.sendKeys 'v0'
  t.sendKey strikethroughKey
  t.expect [
    {
      text:          'hell worl'
      bold:          ' ....    '
    }
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text:          'hell worl'
      bold:          ' ....    '
      strikethrough: '.........'
    }
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text:          'hell worl'
      bold:          ' ....    '
      strikethrough: '    .    '
    }
  ]

new TestCase [
  'blah'
  'blah'
  'blah'
], { name: "visual line mode" }, (t) ->
  t.sendKeys 'Vjj'
  t.sendKey boldKey
  t.expect [
    {
      text: 'blah'
      bold: '....'
    }
    {
      text: 'blah'
      bold: '....'
    }
    {
      text: 'blah'
      bold: '....'
    }
  ]
  t.sendKeys 'ggVjj'
  t.sendKey boldKey
  t.expect [
    'blah'
    'blah'
    'blah'
  ]

new TestCase [
  {
    text: 'blah'
    bold: '... '
    children: [{text: 'fee', bold: '. .'}, 'fi']
  }
  {
    text: 'blah'
    bold: '    '
    children: ['fo', 'fum']
  }
  {
    text: 'blah'
    bold: '   .'
  }
], {}, (t) ->
  t.sendKeys ['V', siblingDownKey, siblingDownKey, boldKey]
  t.expect [
    {
      text: 'blah'
      bold: '....'
      children: [{text: 'fee', bold: '. .'}, 'fi']
    }
    {
      text: 'blah'
      bold: '....'
      children: ['fo', 'fum']
    }
    {
      text: 'blah'
      bold: '....'
    }
  ]
  t.sendKeys ['G', 'V', siblingUpKey, boldKey]
  t.expect [
    {
      text: 'blah'
      bold: '....'
      children: [{text: 'fee', bold: '. .'}, 'fi']
    }
    {
      text: 'blah'
      children: ['fo', 'fum']
    }
    'blah'
  ]
  t.sendKeys ['V', siblingUpKey, boldKey]
  t.expect [
    {
      text: 'blah'
      bold: '....'
      children: [{text: 'fee', bold: '. .'}, 'fi']
    }
    {
      text: 'blah'
      bold: '....'
      children: ['fo', 'fum']
    }
    'blah'
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text: 'blah'
      bold: '....'
      children: [{text: 'fee', bold: '. .'}, 'fi']
    }
    {
      text: 'blah'
      children: ['fo', 'fum']
    }
    'blah'
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text: 'blah'
      bold: '....'
      children: [{text: 'fee', bold: '. .'}, 'fi']
    }
    {
      text: 'blah'
      bold: '....'
      children: ['fo', 'fum']
    }
    {
      text: 'blah'
      bold: '....'
    }
  ]
  t.sendKeys 'u'
  t.expect [
    {
      text: 'blah'
      bold: '... '
      children: [{text: 'fee', bold: '. .'}, 'fi']
    }
    {
      text: 'blah'
      children: ['fo', 'fum']
    }
    {
      text: 'blah'
      bold: '   .'
    }
  ]
