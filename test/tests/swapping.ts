/* globals describe, it */
import TestCase from '../testcase';

describe('swapping blocks', function() {
  it('works', async function() {
    let t = new TestCase([
      { text: 'move', children: [
        'me',
      ] },
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'move', children: [
        'me',
      ] },
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        { text: 'move', children: [
          'me',
        ] },
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'move', children: [
          'me',
        ] },
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          { text: 'move', children: [
            'me',
          ] },
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          { text: 'move', children: [
            'me',
          ] },
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
          { text: 'move', children: [
            'me',
          ] },
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
      { text: 'move', children: [
        'me',
      ] },
    ]);

    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
      { text: 'move', children: [
        'me',
      ] },
    ]);

    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      { text: 'move', children: [
        'me',
      ] },
      '...',
    ]);

    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          { text: 'move', children: [
            'me',
          ] },
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          { text: 'move', children: [
            'me',
          ] },
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'move', children: [
          'me',
        ] },
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        { text: 'move', children: [
          'me',
        ] },
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'move', children: [
        'me',
      ] },
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      { text: 'move', children: [
        'me',
      ] },
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      { text: 'move', children: [
        'me',
      ] },
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres',
        ] },
      ] },
      '...',
    ]);
    await t.done();
  });

  it('swaps past collapsed', async function() {
    let t = new TestCase([
      'line',
      { text: '1', collapsed: true, children: [
        '2',
      ] },
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      { text: '1', collapsed: true, children: [
        '2',
      ] },
      'line',
    ]);
    await t.done();
  });

  it('doesnt swap up past viewroot', async function() {
    let t = new TestCase([
      '0',
      { text: '1', collapsed: true, children: [
        '2',
        '3',
      ] },
    ]);
    t.sendKey('j');
    t.sendKey('enter');
    t.sendKey('j');
    t.sendKey('ctrl+k');
    t.expect([
      '0',
      { text: '1', collapsed: true, children: [
        '2',
        '3',
      ] },
    ]);
    await t.done();
  });

  it('doesnt swap down past viewroot', async function() {
    let t = new TestCase([
      '0',
      { text: '1', collapsed: true, children: [
        '2',
        '3',
      ] },
      '4',
    ]);
    t.sendKey('j');
    t.sendKey('enter');
    t.sendKey('j');
    t.sendKey('j');
    t.sendKey('ctrl+j');
    t.expect([
      '0',
      { text: '1', collapsed: true, children: [
        '2',
        '3',
      ] },
      '4',
    ]);
    await t.done();
  });
});

