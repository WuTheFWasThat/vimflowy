/* globals describe, it */
import TestCase from '../testcase';

describe('swapping blocks', function() {
  it('works', function() {
    let t = new TestCase([
      { text: 'move', children: [
        'me'
      ] },
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'move', children: [
        'me'
      ] },
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        { text: 'move', children: [
          'me'
        ] },
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'move', children: [
          'me'
        ] },
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          { text: 'move', children: [
            'me'
          ] },
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          { text: 'move', children: [
            'me'
          ] },
          'tres'
        ] },
      ] },
      '...'
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
            'me'
          ] },
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...',
      { text: 'move', children: [
        'me'
      ] },
    ]);

    t.sendKey('ctrl+j');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...',
      { text: 'move', children: [
        'me'
      ] },
    ]);

    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      { text: 'move', children: [
        'me'
      ] },
      '...'
    ]);

    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          { text: 'move', children: [
            'me'
          ] },
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          { text: 'move', children: [
            'me'
          ] },
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'move', children: [
          'me'
        ] },
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'uno', children: [
        { text: 'move', children: [
          'me'
        ] },
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      'one',
      { text: 'move', children: [
        'me'
      ] },
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+k');
    t.expect([
      { text: 'move', children: [
        'me'
      ] },
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
    t.sendKey('ctrl+k');
    return t.expect([
      { text: 'move', children: [
        'me'
      ] },
      'one',
      { text: 'uno', children: [
        'two',
        { text: 'dos', children: [
          'three',
          'tres'
        ] },
      ] },
      '...'
    ]);
  });

  return it('swaps past collapsed', function() {
    let t = new TestCase([
      'line',
      { text: '1', collapsed: true, children: [
        '2'
      ] },
    ]);
    t.sendKey('ctrl+j');
    return t.expect([
      { text: '1', collapsed: true, children: [
        '2'
      ] },
      'line'
    ]);
  });
});

