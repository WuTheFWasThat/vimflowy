TestCase = require '../testcase.coffee'

redoKey = 'ctrl+r'

describe "basic multiline tests", () ->
  it "tests basic multiline insertion and movement", () ->
    t = new TestCase ['']
    t.sendKeys 'ione'
    t.sendKey 'esc'
    t.sendKeys 'otwo'
    t.sendKey 'esc'
    t.expect ['one', 'two']
    # test j and k
    t.sendKeys 'kxjx'
    t.expect ['on', 'to']
    # don't go off the edge!
    t.sendKeys 'kkkxjjjx'
    t.expect ['o', 'o']

  it "tests that the final line never goes away", () ->
    t = new TestCase ['unos', 'dos', 'tres', 'quatro']
    t.sendKeys '$jjjx'
    t.expect ['unos', 'dos', 'tres', 'quatr']

  it "tests column -1 works", () ->
    t = new TestCase ['unos', 'dos', 'tres', 'quatro']
    t.sendKeys '$A'
    t.sendKey 'down'
    t.sendKey 'down'
    t.sendKey 'down'
    t.sendKey 'backspace'
    t.expect ['unos', 'dos', 'tres', 'quatr']

  it "tests o and O edge cases", () ->
    t = new TestCase ['a', 's', 'd', 'f']
    t.sendKeys 'Oo'
    t.expect ['o', 'a', 's', 'd', 'f']
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect ['a', 's', 'd', 'f']

    t = new TestCase ['a', 's', 'd', 'f']
    t.sendKeys '5joO'
    t.expect ['a', 's', 'd', 'f', 'O']
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect ['a', 's', 'd', 'f']

    t = new TestCase ['a', 's', 'd', 'f']
    t.sendKeys 'oO'
    t.expect ['a', 'O', 's', 'd', 'f']
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect ['a', 's', 'd', 'f']

    t = new TestCase ['a', 's', 'd', 'f']
    t.sendKeys '5jOo'
    t.expect ['a', 's', 'd', 'o', 'f']
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect ['a', 's', 'd', 'f']

  it "tests o and O undo and redo", () ->
    threeRows = [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]

    t = new TestCase threeRows
    t.sendKeys 'Oo'
    t.expect [
      'o',
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect threeRows
    t.sendKey redoKey
    t.expect [
      'o',
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]

    t = new TestCase threeRows
    t.sendKeys 'oO'
    t.expect [
      { text: 'top row', children: [
        'O',
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect threeRows
    t.sendKey redoKey
    t.expect [
      { text: 'top row', children: [
        'O',
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]

    t = new TestCase threeRows
    t.sendKeys 'jOo'
    t.expect [
      { text: 'top row', children: [
        'o',
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect threeRows
    t.sendKey redoKey
    t.expect [
      { text: 'top row', children: [
        'o',
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
    ]

    t = new TestCase threeRows
    t.sendKeys 'joO'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'O',
          'bottom row'
        ] },
      ] },
    ]
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect threeRows
    t.sendKey redoKey
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'O',
          'bottom row'
        ] },
      ] },
    ]

    t = new TestCase threeRows
    t.sendKeys '2jOo'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'o',
          'bottom row'
        ] },
      ] },
    ]
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect threeRows
    t.sendKey redoKey
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'o',
          'bottom row'
        ] },
      ] },
    ]

    t = new TestCase threeRows
    t.sendKeys '2joO'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row',
          'O'
        ] },
      ] },
    ]
    t.sendKey 'esc'
    t.sendKeys 'u'
    t.expect threeRows
    t.sendKey redoKey
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row',
          'O'
        ] },
      ] },
    ]

  it "skips collapsed children", () ->
    t = new TestCase [
      { text: 'a', collapsed: true, children: [
        's', 'd'
      ] },
      'f'
    ]
    t.sendKeys 'oo'
    t.expect [
      { text: 'a', collapsed: true, children: [
        's', 'd'
      ] },
      'o'
      'f'
    ]

  it "tricky -1 col case", () ->
    t = new TestCase [
      'a row'
      'another row'
      'a third row'
    ]
    t.sendKeys '$jx'
    t.expect [
      'a row'
      'another ro'
      'a third row'
    ]
    t.sendKeys 'd0x'
    t.expect [
      'a row'
      ''
      'a third row'
    ]
    # tricky -1 on empty row case
    t.sendKeys 'j$k'
    t.sendKeys 'iab'
    t.expect [
      'a row'
      'ab'
      'a third row'
    ]

  it "tests basic deletion", () ->
    t = new TestCase [
      'a row'
      'another row'
      'a third row'
    ]
    t.sendKeys 'ddjdd'
    t.expect [
      'another row'
    ]
    t.sendKeys 'ux'
    t.expect [
      'another row'
      ' third row'
    ]

  it "tests deletion moves cursor properly", () ->
    t = new TestCase [
      { text: 'here', children: [
        { text: 'and', children: [
          'there'
        ] },
      ] },
      'down here'
    ]
    t.sendKeys 'G'
    t.expectCursor 4, 0
    t.sendKeys 'dd'
    t.expectCursor 3, 0

    t = new TestCase [
      { text: 'here', children: [
        { text: 'and', collapsed: true, children: [
          'there'
        ] },
      ] },
      'down here'
    ]
    t.sendKeys 'G'
    t.expectCursor 4, 0
    t.sendKeys 'dd'
    t.expectCursor 2, 0

  it "cursor moves correctly when last sibling is deleted", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys '3jdd'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys 'x'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
            'ottom row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys '2u'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]

  it "cursor moves correctly when first sibling is deleted", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys '2jdd'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys 'x'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys '2u'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]

  it "creates a new row when last sibling is deleted", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys 'dd'
    t.expect [ 'another row' ]

    # automatically creates a new row
    t.sendKeys 'dd'
    t.expect [ '' ]
    t.sendKeys 'u'
    t.expect [ 'another row' ]

    # brings back everything!
    t.sendKeys 'u'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]

  it "handles deletion of everything", () ->
    t = new TestCase [ 'row', 'row', 'row your boat' ]
    t.sendKeys '4dd'
    t.expect ['']
    t.sendKey 'u'
    t.expect [ 'row', 'row', 'row your boat' ]

  it "basic change row works", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys 'cc'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [
      { text: 'a row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    # should paste properly
    t.sendKeys 'p'
    t.expect [
      { text: 'a row', children: [
        'top row'
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]

  it "basic recursive change row works", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
      'another row'
    ]
    t.sendKeys 'cr'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [ 'a row', 'another row' ]
    t.sendKeys 'u'

  it "change recursive works on row with children", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
    ]
    t.sendKeys 'cr'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [ 'a row' ]
    t.sendKeys 'u'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
          'bottomest row'
        ] },
      ] },
    ]

  it "tests recursive change on children", () ->
    t = new TestCase [
      { text: 'top row', children: [
        'middle row'
        'bottom row'
      ] },
    ]
    t.sendKeys 'jcr'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [
      { text: 'top row', children: [
        'a row'
        'bottom row'
      ] },
    ]
    t.sendKey 'u'
    t.sendKeys 'jcr'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [
      { text: 'top row', children: [
        'middle row'
        'a row'
      ] },
    ]

  it "tests cursor returns to where it was", () ->
    t = new TestCase [
      'top row',
      'middle row'
      'bottom row'
    ]
    t.sendKeys 'dd'
    t.sendKeys 'jj'
    t.sendKeys 'ux'
    t.expect
    t.expect [
      'op row',
      'middle row',
      'bottom row',
    ]

  it "tests cursor returns to where it was after undo+redo+undo", () ->
    t = new TestCase [
      'top row',
      'middle row'
      'bottom row'
    ]
    t.sendKeys 'dd'
    t.sendKeys 'jj'
    t.sendKeys 'u'
    t.sendKey 'ctrl+r'
    t.sendKeys 'ux'
    t.expect
    t.expect [
      'op row',
      'middle row',
      'bottom row',
    ]

  it "tests redo in tricky case removing last row", () ->
    t = new TestCase [ 'a row' ]
    t.sendKeys 'cr'
    t.sendKeys 'new row'
    t.sendKey 'esc'
    t.expect [ 'new row' ]
    t.sendKeys 'u'
    t.sendKey 'ctrl+r'
    t.sendKeys 'x'
    t.expect [ 'new ro' ]
    t.sendKeys 'uu'
    t.expect [ 'a row' ]
    t.sendKey 'ctrl+r'
    t.expect [ 'new row' ]
    t.sendKey 'ctrl+r'
    t.expect [ 'new ro' ]

  it "tests new row creation works", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children: [
          'bottom row'
        ] }
      ] },
    ]
    t.sendKeys 'jjcr'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children: [
          'a row'
        ] },
      ] },
    ]

  it "tests changing too many rows works", () ->
    t = new TestCase [
      { text: 'top row', children: [
        { text: 'middle row', children: [
          'bottom row'
        ] },
      ] },
    ]
    t.sendKeys 'jj2cr'
    t.sendKeys 'a row'
    t.sendKey 'esc'
    t.expect [
      { text: 'top row', children: [
        { text: 'middle row', children: [
          'a row'
        ] },
      ] },
    ]

  it "tests deleting too many rows works", () ->
    t = new TestCase [
      { text: 'parent row', children: [
        'child row 1'
        'child row 2'
      ] },
    ]
    t.sendKeys 'j3dd'
    t.expect [ 'parent row' ]
    t.sendKeys 'u'
    t.expect [
      { text: 'parent row', children: [
        'child row 1'
        'child row 2'
      ] },
    ]

  it "tests undo on change", () ->
    t = new TestCase [
      { text: 'parent row', children: [
        'child row 1'
        { text: 'child row 2', children: [
          'baby 1'
          'baby 2'
          'baby 3'
        ] },
      ] },
    ]
    t.sendKeys '2j2cr' # despite the 2cr, deletes only one, but deletes all the children
    t.sendKeys 'deleted'
    t.sendKey 'esc'
    t.expect [
      { text: 'parent row', children: [
        'child row 1'
        'deleted'
      ] },
    ]
    t.sendKeys 'u'
    t.expect [
      { text: 'parent row', children: [
        'child row 1'
        { text: 'child row 2', children: [
          'baby 1'
          'baby 2'
          'baby 3'
        ] },
      ] },
    ]

  it "tests redo in tricky case making sure redo re-creates the same row", () ->
    t = new TestCase [ 'a row' ]
    t.sendKeys 'cr'
    t.sendKeys 'new row'
    t.sendKey 'esc'
    t.expect [ 'new row' ]
    t.sendKeys 'u'
    t.sendKey 'ctrl+r'
    t.sendKeys 'x'
    t.expect [ 'new ro' ]
    t.sendKeys 'uu'
    t.expect [ 'a row' ]
    # to demonstrate we're not relying on getId behavior
    t.document.getId = () ->
        id = 0
        while @lines[id]
          id++
        return id+1
    t.sendKey 'ctrl+r'
    t.expect [ 'new row' ]
    t.sendKey 'ctrl+r'
    t.expect [ 'new ro' ]

  it "tests redo in tricky case making sure redo paste re-creates the same row", () ->
    t = new TestCase [ 'a row' ]
    t.sendKeys 'yyp'
    t.expect [
      'a row'
      'a row'
    ]
    t.sendKeys 'u'
    t.sendKey 'ctrl+r'
    t.sendKeys 'x'
    t.expect [
      'a row'
      ' row'
    ]
    t.sendKeys 'uu'
    t.expect [ 'a row' ]
    # to demonstrate we're not relying on getId behavior
    t.document.getId = () ->
        id = 0
        while @lines[id]
          id++
        return id+1
    t.sendKey 'ctrl+r'
    t.expect [
      'a row'
      'a row'
    ]
    t.sendKey 'ctrl+r'
    t.expect [
      'a row'
      ' row'
    ]

  it "tests deleting viewroot", () ->
    t = new TestCase [
      { text: 'here', children: [
        'there'
      ] },
    ]
    t.sendKeys 'j'
    t.sendKey 'enter'
    t.expectViewRoot 2
    t.sendKeys 'dd'
    t.expectViewRoot 1

  it "tests editing viewroot", () ->
    t = new TestCase [
      { text: 'here', children: [
        'there'
      ] },
    ]
    t.sendKeys 'j'
    t.sendKey 'enter'
    t.expectViewRoot 2
    t.sendKeys 'dd'
    t.expectViewRoot 1

