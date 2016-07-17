/* globals describe, it */
import TestCase from '../testcase';

describe('backspace', function() {
  it('works in simple case', function() {
    let t = new TestCase(['abc']);
    t.sendKey('A');
    t.sendKey('backspace');
    t.sendKey('backspace');
    return t.expect(['a']);
  });

  it('works deleting from second line', function() {
    let t = new TestCase(['abc', 'def']);
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
    return t.expect(['abc', 'def']);
  });

  it('works at end of line', function() {
    let t = new TestCase(['ab', 'cd']);
    t.sendKeys('jA');
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.expect(['ab', '']);
    t.sendKey('backspace');
    t.expect(['ab']);
    t.sendKey('backspace');
    return t.expect(['a']);
  });

  it('works from children', function() {
    let t = new TestCase([
      { text: 'ab', children: [
        'bc'
      ] },
      { text: 'cd', children: [
        'de'
      ] }
    ]);
    t.sendKeys('jji');
    t.sendKey('backspace');
    // did nothing due to child of 'ab'
    t.expect([
      { text: 'ab', children: [
        'bc'
      ] },
      { text: 'cd', children: [
        'de'
      ] }
    ]);
    t.sendKey('esc');
    t.sendKeys('kddj');
    t.expect([
      'ab',
      { text: 'cd', children: [
        'de'
      ] }
    ]);
    t.sendKeys('i');
    t.sendKey('backspace');
    t.expect([
      { text: 'abcd', children: [
        'de'
      ] },
    ]);
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.sendKey('backspace');
    t.expect([
      { text: 'cd', children: [
        'de'
      ] },
    ]);
    t.sendKey('backspace');
    return t.expect([
      { text: 'cd', children: [
        'de'
      ] },
    ]);
  });

  it('works with undo/redo', function() {
    let t = new TestCase([
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
    t.sendKeys('ji');
    t.sendKey('backspace');
    t.expect([
      'abcd'
    ]);
    // t.sendKey('backspace');
    // t.expect([
    //   'acd'
    // ]);
    t.sendKey('esc');
    t.sendKeys('u');
    t.expect([
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
    t.sendKey('ctrl+r');
    t.expect([
      'abcd'
    ]);
    t.sendKey('x');
    return t.expect([
      'acd'
    ]);
  });

  return it('fails when both rows have children', function() {
    let t = new TestCase([
      { text: 'ab', children: [
        'cd'
      ] },
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
    t.sendKeys('jji');
    t.sendKey('backspace');
    t.expect([
      { text: 'ab', children: [
        'cd'
      ] },
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
    t.sendKey('esc');
    t.sendKeys('kdd');
    t.expect([
      'ab',
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
    t.sendKeys('ji');
    t.sendKey('backspace');
    t.expect([
      { text: 'abab', children: [
        'cd'
      ] }
    ]);
    t.sendKey('backspace');
    t.expect([
      { text: 'aab', children: [
        'cd'
      ] }
    ]);
    t.sendKey('esc');
    t.sendKeys('u');
    return t.expect([
      'ab',
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
  });
});


describe('delete', () =>
  it('works in basic case', function() {
    let t = new TestCase(['ab', 'cd']);
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
    return t.expect(['ab', 'cd']);
  })
);

