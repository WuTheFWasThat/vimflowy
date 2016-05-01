TestCase = require '../testcase.coffee'

describe "export", () ->
  it "works in basic case", () ->
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

  it "doesnt care about zoom", () ->
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

describe "import", () ->
  it "works from text format", () ->
    t = new TestCase ['']
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
            { text: 'Line 2', collapsed: true, children: [
                { text: "Line 2.1" },
                { text: "Line 2.2", collapsed: true, children: [
                    { text: "Line 2.2.1" }
                ] },
                { text: "Line 2.3", collapsed: true, children: [
                    { text: "Line 2.3.1" }
                ] }
            ] },
            { text: 'Line 3' }
        ] }, null, 2)

  it "works from json format", () ->
    t = new TestCase ['']
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

    # move the imported text out to the root
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

  it "works from workflowy text format", () ->
    t = new TestCase ['']
    t.import """- [COMPLETE] Line 1
                  - Subpart 1
                  "Title line for subpart 1"
                - [COMPLETE] Line 2
                - [COMPLETE] Line 3""", "text/plain"

    # move the imported text out to the root
    t.sendKey 'down'
    t.sendKeys ['3', 'shift+tab']
    t.sendKey 'up'
    t.sendKeys 'dd'

    t.expectExport 'application/json',
      (JSON.stringify {
        text: '', children: [
            { text: 'Line 1', collapsed: true, children: [
                { text: "Subpart 1", collapsed: true, children: [
                    { text: "Title line for subpart 1" }
                ] }
            ] },
            { text: 'Line 2' },
            { text: 'Line 3' }
        ] }, null, 2)
