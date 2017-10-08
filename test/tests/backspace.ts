/* globals describe, it */
import TestCase from '../testcase';

describe('backspace', function () {
  it('works in simple case', async function () {
    const t = new TestCase(['abc']);
    t.sendKey('A');
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.expect(['a']);
    await t.done();
  });

  it('works deleting from second line', async function () {
    const t = new TestCase(['abc', 'def']);
    t.sendKeys('jli');
    t.sendKey('backspace');
    t.expect(['abc', 'ef']);
    t.sendKey('backspace');
    t.expect(['abcef']);
    t.sendKey('backspace');
    t.expect(['abef']);
    t.sendKey('backspace');
    t.expect(['aef']);
    t.sendKey('backspace');
    t.expect(['ef']);
    t.sendKey('backspace');
    t.expect(['ef']);
    t.sendKey('esc');
    t.sendKey('u');
    t.expect(['abc', 'def']);
    await t.done();
  });

  it('works at end of line', async function () {
    const t = new TestCase(['ab', 'cd']);
    t.sendKeys('jA');
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.expect(['ab', '']);
    t.sendKey('backspace');
    t.expect(['ab']);
    t.sendKey('backspace');
    t.expect(['a']);
    await t.done();
  });

  it('works from children', async function () {
    const t = new TestCase([
      {
        text: 'ab', children: [
          'bc',
        ]
      },
      {
        text: 'cd', children: [
          'de',
        ]
      },
    ]);
    t.sendKeys('jji');
    t.sendKey('backspace');
    // did nothing due to child of 'ab'
    t.expect([
      {
        text: 'ab', children: [
          'bc',
        ]
      },
      {
        text: 'cd', children: [
          'de',
        ]
      },
    ]);
    t.sendKey('esc');
    t.sendKeys('kddj');
    t.expect([
      'ab',
      {
        text: 'cd', children: [
          'de',
        ]
      },
    ]);
    t.sendKeys('i');
    t.sendKey('backspace');
    t.expect([
      {
        text: 'abcd', children: [
          'de',
        ]
      },
    ]);
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.expect([
      {
        text: 'cd', children: [
          'de',
        ]
      },
    ]);
    t.sendKey('backspace');
    t.expect([
      {
        text: 'cd', children: [
          'de',
        ]
      },
    ]);
    await t.done();
  });

  it('works with undo/redo', async function () {
    const t = new TestCase([
      {
        text: 'ab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKeys('ji');
    t.sendKey('backspace');
    t.expect([
      'abcd',
    ]);
    t.expectCursor(1, 2);
    // t.sendKey('backspace');
    // t.expect([
    //   'acd'
    // ]);
    t.sendKey('esc');
    t.expectCursor(1, 1);
    t.sendKeys('u');
    t.expect([
      {
        text: 'ab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKey('ctrl+r');
    t.expect([
      'abcd',
    ]);
    t.expectCursor(1, 1);
    t.sendKey('x');
    t.expect([
      'acd',
    ]);
    await t.done();
  });

  it('fails when both rows have children', async function () {
    const t = new TestCase([
      {
        text: 'ab', children: [
          'cd',
        ]
      },
      {
        text: 'ab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKeys('jji');
    t.sendKey('backspace');
    t.expect([
      {
        text: 'ab', children: [
          'cd',
        ]
      },
      {
        text: 'ab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKey('esc');
    t.sendKeys('kdd');
    t.expect([
      'ab',
      {
        text: 'ab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKeys('ji');
    t.sendKey('backspace');
    t.expect([
      {
        text: 'abab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKey('backspace');
    t.expect([
      {
        text: 'aab', children: [
          'cd',
        ]
      },
    ]);
    t.sendKey('esc');
    t.sendKeys('u');
    t.expect([
      'ab',
      {
        text: 'ab', children: [
          'cd',
        ]
      },
    ]);
    await t.done();
  });
});


describe('delete', () =>
  it('works in basic case', async function () {
    const t = new TestCase(['ab', 'cd']);
    t.sendKeys('i');
    t.sendKey('delete');
    t.expect(['b', 'cd']);
    t.sendKey('delete');
    t.expect(['', 'cd']);
    // doesn't do anything, for now
    t.sendKey('delete');
    t.expect(['', 'cd']);
    t.sendKey('esc');
    t.sendKey('u');
    t.expect(['ab', 'cd']);
    await t.done();
  })
);

