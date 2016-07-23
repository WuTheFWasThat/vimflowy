/* globals describe, it */
import TestCase from '../testcase';

describe('export', function() {
  it('works in basic case', async function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    t.expectExport('text/plain', '- \n  - first\n    - second\n  - third');
    t.expectExport('application/json',
      (JSON.stringify({
        text: '', children: [
          { text: 'first', children: [
            { text: 'second' }
          ] },
          { text: 'third' }
        ]
      }, null, 2))
    );
    await t.done();
  });

  it('doesnt care about zoom', async function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    t.sendKey('down');
    t.sendKey('alt+l');
    t.expectExport('text/plain', '- \n  - first\n    - second\n  - third');
    t.expectExport('application/json',
      (JSON.stringify({
        text: '', children: [
          { text: 'first', children: [
            { text: 'second' }
          ] },
          { text: 'third' }
        ]}, null, 2))
    );
    await t.done();
  });
});

describe('import', function() {
  it('works from text format', async function() {
    let t = new TestCase(['']);
    t.import(
`- Line 1
- Line 2
  - Line 2.1
  - Line 2.2
    - Line 2.2.1
  - Line 2.3
    - Line 2.3.1
- Line 3
`, 'text/plain');
    t.sendKey('down');
    t.sendKeys(['3', 'shift+tab']);
    t.sendKey('up');
    t.sendKeys('dd');
    t.expectExport('application/json',
      (JSON.stringify({
        text: '', children: [
            { text: 'Line 1' },
            { text: 'Line 2', collapsed: true, children: [
                { text: 'Line 2.1' },
                { text: 'Line 2.2', collapsed: true, children: [
                    { text: 'Line 2.2.1' }
                ] },
                { text: 'Line 2.3', collapsed: true, children: [
                    { text: 'Line 2.3.1' }
                ] }
            ] },
            { text: 'Line 3' }
        ] }, null, 2))
    );
    await t.done();
  });

  it('works from json format', async function() {
    let t = new TestCase(['']);
    t.import((JSON.stringify({
      'text': '',
      'children': [
        {
          'text': 'Line 1'
        },
        {
          'text': 'Line 2',
          'children': [
            {
              'text': 'Line 2.1'
            },
            {
              'text': 'Line 2.2',
              'children': [
                {
                  'text': 'Line 2.2.1'
                }
              ]
            },
            {
              'text': 'Line 2.3',
              'children': [
                {
                  'text': 'Line 2.3.1'
                }
              ]
            }
          ]
        },
        {
          'text': 'Line 3'
        }
      ]
    })), 'application/json');

    // move the imported text out to the root
    t.sendKey('down');
    t.sendKeys(['3', 'shift+tab']);
    t.sendKey('up');
    t.sendKeys('dd');

    t.expectExport('application/json',
      (JSON.stringify({
        text: '', children: [
            { text: 'Line 1' },
            { text: 'Line 2', children: [
                { text: 'Line 2.1' },
                { text: 'Line 2.2', children: [
                    { text: 'Line 2.2.1' }
                ] },
                { text: 'Line 2.3', children: [
                    { text: 'Line 2.3.1' }
                ] }
            ] },
            { text: 'Line 3' }
        ]
      }, null, 2))
    );
    await t.done();
  });

  it('works from workflowy text format', async function() {
    let t = new TestCase(['']);
    t.import(
`- [COMPLETE] Line 1
  - Subpart 1
  "Title line for subpart 1"
- [COMPLETE] Line 2
- [COMPLETE] Line 3
`, 'text/plain');

    // move the imported text out to the root
    t.sendKey('down');
    t.sendKeys(['3', 'shift+tab']);
    t.sendKey('up');
    t.sendKeys('dd');

    t.expectExport('application/json',
      (JSON.stringify({
        text: '', children: [
            { text: 'Line 1', collapsed: true, children: [
                { text: 'Subpart 1', collapsed: true, children: [
                    { text: 'Title line for subpart 1' }
                ] }
            ] },
            { text: 'Line 2' },
            { text: 'Line 3' }
        ] }, null, 2))
    );
    await t.done();
  });

  it('works with clones', async function() {
    let t = new TestCase(['']);
    t.import((JSON.stringify({
      'text': '',
      'children': [
        {
          'text': 'item',
          'children': [
            {
              'text': 'clone',
              'id': 94
            }
          ]
        },
        {
          'clone': 94
        }
      ]
    })), 'application/json');

    t.expect([
      {
        'text': '',
        'children': [
          {
            'text': 'item',
            'children': [
              {
                'text': 'clone',
                'id': 3
              }
            ]
          },
          {
            'clone': 3
          }
        ]
      }
    ]);

    t.expectExport('application/json', (JSON.stringify({
      'text': '',
      'children': [
        {
          'text': '',
          'children': [
            {
              'text': 'item',
              'children': [
                {
                  'text': 'clone',
                  'id': 3
                }
              ]
            },
            {
              'clone': 3
            }
          ]
        }
      ]
    }, null, 2)));
    await t.done();
  });
});
