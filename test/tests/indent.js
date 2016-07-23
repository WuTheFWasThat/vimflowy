/* globals describe, it */
import TestCase from '../testcase';

let indentBlockKey = 'tab';
let unindentBlockKey = 'shift+tab';
let indentRowKey = '>';
let unindentRowKey = '<';

describe('block indent/unindent', function() {
  let threeRows = [
    { text: 'top row', children: [
      { text: 'middle row', children : [
        'bottom row'
      ] },
    ] },
  ];

  it('works in basic cases', async function() {
    let t = new TestCase(threeRows);
    t.sendKey(indentBlockKey);
    t.expect(threeRows);
    t.sendKeys('j');
    t.sendKey(indentBlockKey);
    t.expect(threeRows);
    t.sendKeys('j');
    t.sendKey(indentBlockKey);
    t.expect(threeRows);
    t.sendKey(unindentBlockKey);
    t.expect([
      { text: 'top row', children: [
        'middle row',
        'bottom row',
      ] }
    ]);
    t.sendKeys('u');
    t.expect(threeRows);
    await t.done();
  });

  it('moves past siblings and undoes', async function() {
    let t = new TestCase([
      { text: 'a', children: [
        { text: 'ab', children : [
          'abc'
        ] },
        { text: 'ad', children : [
          'ade'
        ] },
      ] },
    ]);
    t.sendKeys('j');
    t.sendKey(unindentBlockKey);
    t.expect([
      { text: 'a', children : [
        { text: 'ad', children : [
          'ade'
        ] },
      ] },
      { text: 'ab', children: [
        'abc',
      ] },
    ]);
    t.sendKey(indentBlockKey);
    t.expect([
      { text: 'a', children: [
        { text: 'ad', children : [
          'ade'
        ] },
        { text: 'ab', children: [
          'abc',
        ] },
      ] }
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'a', children : [
        { text: 'ad', children : [
          'ade'
        ] },
      ] },
      { text: 'ab', children: [
        'abc',
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'a', children: [
        { text: 'ab', children : [
          'abc'
        ] },
        { text: 'ad', children : [
          'ade'
        ] },
      ] },
    ]);
    await t.done();
  });

  it('uncollapses if indenting into collapsed', async function() {
    let t = new TestCase([
      { text: '1', collapsed: true, children: [
        '2'
      ] },
      { text: '3', children: [
        '4'
      ] },
    ]);
    t.sendKeys('j');
    t.sendKey(indentBlockKey);
    t.expect([
      { text: '1', children: [
        '2',
        { text: '3', children: [
          '4'
        ] },
      ] },
    ]);
    await t.done();
  });

  it('works with something with children', async function() {
    let t = new TestCase([
      { text: '1', collapsed: true, children: [
        '2'
      ] },
      { text: '3', children: [
        '4'
      ] },
    ]);
    t.sendKeys('j');
    t.sendKey(indentBlockKey);
    t.expect([
      { text: '1', children: [
        '2',
        { text: '3', children: [
          '4'
        ] },
      ] },
    ]);
    await t.done();
  });

  it('works with numbers', async function() {
    let t = new TestCase([
      { text: 'mama', children: [
        { text: 'oldest kid', children : [
          'grandkid'
        ] },
        'middle kid',
        'young kid'
      ] },
    ]);
    t.sendKeys('jjj2');
    t.sendKey(indentBlockKey);
    t.expect([
      { text: 'mama', children: [
        { text: 'oldest kid', children : [
          'grandkid',
          'middle kid',
          'young kid'
        ] },
      ] },
    ]);
    await t.done();
  });

  it('works with numbers, somewhat trickier case leaving 1 sibling', async function() {
    let t = new TestCase([
      { text: 'mama', children: [
        { text: 'oldest kid', collapsed: true, children : [
          'grandkid'
        ] },
        { text: 'middle kid', children : [
          'grandkid 2'
        ] },
        'young kid'
      ] },
    ]);
    t.sendKeys('jj2');
    t.sendKey(indentBlockKey);
    t.expect([
      { text: 'mama', children: [
        { text: 'oldest kid', children : [
          'grandkid',
          { text: 'middle kid', children : [
            'grandkid 2'
          ] },
          'young kid'
        ] },
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'mama', children: [
        { text: 'oldest kid', collapsed: true, children : [
          'grandkid'
        ] },
        { text: 'middle kid', children : [
          'grandkid 2'
        ] },
        'young kid'
      ] },
    ]);
    t.sendKeys('k2');
    t.sendKey(unindentBlockKey);
    t.expect([
      { text: 'mama', children : [
        'young kid'
      ] },
      { text: 'oldest kid', collapsed: true, children : [
        'grandkid'
      ] },
      { text: 'middle kid', children : [
        'grandkid 2'
      ] },
    ]);
    await t.done();
  });
});

describe('random tests', () =>
  it('tests random things', async function() {
    let t = new TestCase([
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'bottom row'
        ] },
      ] },
      'another row'
    ]);
    t.sendKeys('2jx');
    t.expect([
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row'
        ] },
      ] },
      'another row'
    ]);
    t.sendKeys('jx');
    t.expect([
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row'
        ] },
      ] },
      'nother row'
    ]);
    t.sendKey(indentBlockKey);
    t.sendKey(indentBlockKey);
    t.expect([
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row',
          'nother row'
        ] },
      ] },
    ]);
    t.sendKeys('uu');
    t.expect([
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row'
        ] },
      ] },
      'nother row'
    ]);
    t.sendKey('ctrl+r');
    t.sendKey('ctrl+r');
    t.expect([
      { text: 'top row', children: [
        { text: 'middle row', children : [
          'ottom row',
          'nother row'
        ] },
      ] },
    ]);
    t.sendKeys('k');
    t.sendKey(unindentRowKey);
    t.expect([
      { text: 'top row', children: [
        'middle row',
        { text: 'ottom row', children : [
          'nother row'
        ] },
      ] },
    ]);
    t.sendKey(unindentRowKey);
    t.expect([
      { text: 'top row', children: [
        'middle row',
        { text: 'ottom row', children : [
          'nother row'
        ] },
      ] },
    ]);
    t.sendKeys('k');
    t.sendKey(unindentRowKey);
    t.expect([
      'top row',
      { text: 'middle row', children: [
        { text: 'ottom row', children : [
          'nother row'
        ] },
      ] },
    ]);
    t.sendKey('ctrl+l');
    t.expect([
      { text: 'top row', children: [
        { text: 'middle row', children: [
          { text: 'ottom row', children : [
            'nother row'
          ] },
        ] },
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      'top row',
      { text: 'middle row', children: [
        { text: 'ottom row', children : [
          'nother row'
        ] },
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'top row', children: [
        'middle row',
        { text: 'ottom row', children : [
          'nother row'
        ] },
      ] },
    ]);
    t.sendKeys('j');
    t.sendKey('ctrl+h');
    t.expect([
      { text: 'top row', children: [
        'middle row'
      ] },
      { text: 'ottom row', children : [
        'nother row'
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'top row', children: [
        'middle row',
        { text: 'ottom row', children : [
          'nother row'
        ] },
      ] },
    ]);
    await t.done();
  })
);

describe('row indent/unindent', function() {
  it('works in basic cases', async function() {
    let t = new TestCase([
      '0',
      { text: '1', children: [
        '2'
      ] },
    ]);
    t.sendKeys('j');
    t.sendKey(indentRowKey);
    t.expect([
      { text: '0', children: [
        '1',
        '2'
      ] },
    ]);
    await t.done();
  });

  it('works like indent block when collapsed', async function() {
    let t = new TestCase([
      { text: 'grandmama', children: [
        { text: 'mama', collapsed: true, children : [
          'me'
        ] },
      ] },
    ]);
    t.sendKeys(['j', unindentRowKey]);
    t.expect([
      'grandmama',
      { text: 'mama', collapsed: true, children : [
        'me'
      ] }
    ]);

    t.sendKey(indentRowKey);
    t.expect([
      { text: 'grandmama', children: [
        { text: 'mama', collapsed: true, children : [
          'me'
        ] },
      ] },
    ]);
    await t.done();
  });


  it("can't indent the viewroot", async function() {
    let t = new TestCase([
      'blah',
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]);
    t.expectViewRoot(0);
    t.sendKeys('j]');
    t.expectViewRoot(2);
    t.sendKey(indentRowKey);
    t.expect([
      'blah',
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]);
    t.expectViewRoot(2);
    t.sendKey(indentBlockKey);
    t.expect([
      'blah',
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] },
      ] },
    ]);
    t.expectViewRoot(2);
    await t.done();
  });

  it("can't unindent the viewroot", async function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second'
      ] },
    ]);
    t.expectViewRoot(0);
    t.sendKey(']');
    t.expectViewRoot(1);
    t.sendKey(unindentRowKey);
    t.expect([
      { text: 'first', children: [
        'second'
      ] },
    ]);
    t.expectViewRoot(1);
    t.sendKey(indentBlockKey);
    t.expect([
      { text: 'first', children: [
        'second'
      ] },
    ]);
    t.expectViewRoot(1);
    await t.done();
  });

  it('multi indent does as many as it can', async function() {
    let t = new TestCase([
      'first',
      'second',
      'third'
    ]);
    t.sendKey('j');
    t.sendKey('3');
    t.sendKey(indentBlockKey);
    t.expect([
      { text: 'first', children: [
        'second',
        'third'
      ] },
    ]);
    t.sendKey('3');
    t.sendKey(unindentBlockKey);
    t.expect([
      'first',
      'second',
      'third'
    ]);
    await t.done();
  });
});
