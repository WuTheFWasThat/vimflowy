TestCase = require '../testcase.coffee'

new TestCase [
  { text: 'first', children: [
    'second'
  ] },
  'third'
], { name: "Test export formats" }, (t) ->
  t.expectExport 'text/plain', "- \n  - first\n    - second\n  - third"
  t.expectExport 'application/json',
    (JSON.stringify {
      text: '', children: [
        { text: 'first', children: [
          { text: 'second' }
        ] },
        { text: 'third' }
    ]}, null, 2)

new TestCase [
  { text: 'first', children: [
    'second'
  ] },
  'third'
], { name: "Make sure zoom does not affect export" }, (t) ->
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

new TestCase [''], { name: "Test vimflowy text import" }, (t) ->
  t.import """- Line 1
              - Line 2
                - Line 2.1
                - Line 2.2
                  - Line 2.2.1
                - Line 2.3
                  - Line 2.3.1
              - Line 3""", 'text/plain'
  t.sendKey 'down'
  t.sendKeys ['3', 'shift+tab']
  t.sendKey 'up'
  t.sendKeys 'dd'
  t.expectExport 'application/json',
    (JSON.stringify {
      text: '', children: [
          { text: 'Line 1' },
          { text: 'Line 2', children: [
              { text: "Line 2.1" },
              { text: "Line 2.2", children: [
                  { text: "Line 2.2.1" }
              ], collapsed: true },
              { text: "Line 2.3", children: [
                  { text: "Line 2.3.1" }
              ], collapsed: true }
          ], collapsed: true },
          { text: 'Line 3' }
      ] }, null, 2)

new TestCase [''], { name: "Test vimflowy json import" }, (t) ->
  t.import """{
    "text": "",
    "children": [
      {
        "text": "Line 1"
      },
      {
        "text": "Line 2",
        "children": [
          {
            "text": "Line 2.1"
          },
          {
            "text": "Line 2.2",
            "children": [
              {
                "text": "Line 2.2.1"
              }
            ]
          },
          {
            "text": "Line 2.3",
            "children": [
              {
                "text": "Line 2.3.1"
              }
            ]
          }
        ]
      },
      {
        "text": "Line 3"
      }
    ]
  }""", 'application/json'
  t.sendKey 'down'
  t.sendKeys ['3', 'shift+tab']
  t.sendKey 'up'
  t.sendKeys 'dd'
  t.expectExport 'application/json',
    (JSON.stringify {
      text: '', children: [
          { text: 'Line 1' },
          { text: 'Line 2', children: [
              { text: "Line 2.1" },
              { text: "Line 2.2", children: [
                  { text: "Line 2.2.1" }
              ] },
              { text: "Line 2.3", children: [
                  { text: "Line 2.3.1" }
              ] }
          ] },
          { text: 'Line 3' }
    ] }, null, 2)

new TestCase [''], { name: "Test workflowy import" }, (t) ->
  t.import """- [COMPLETE] Line 1
                - Subpart 1
                "Title line for subpart 1"
              - [COMPLETE] Line 2
              - [COMPLETE] Line 3""", "text/plain"
  t.sendKey 'down'
  t.sendKeys ['3', 'shift+tab']
  t.sendKey 'up'
  t.sendKeys 'dd'
  t.expectExport 'application/json',
    (JSON.stringify {
      text: '', children: [
          { text: 'Line 1', children: [
              { text: "Subpart 1", children: [
                  { text: "Title line for subpart 1" }
              ], collapsed: true }
          ], collapsed: true },
          { text: 'Line 2' },
          { text: 'Line 3' }
      ] }, null, 2)
