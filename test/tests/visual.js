/* globals describe, it */
import TestCase from '../testcase';

describe('visual mode', function() {
  it('works with basic motions', function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('vwx');
    t.expect(['orld']);

    t = new TestCase(['hello world']);
    t.sendKeys('vex');
    t.expect([' world']);

    t = new TestCase(['hello world']);
    t.sendKeys('v$x');
    t.expect(['']);

    t = new TestCase(['hello world']);
    t.sendKeys('wv3lx');
    return t.expect(['hello d']);
  });

  it('keeps cursor after canceling', function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('vw');
    t.sendKey('esc');
    t.sendKeys('x');
    return t.expect(['hello orld']);
  });

  it('allows cursor swap', function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('wv3lo3hx');
    t.expect(['held']);
    t.sendKeys('u');
    return t.expect(['hello world']);
  });

  it('moves cursor back if needed', function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('v$');
    t.sendKey('esc');
    t.sendKeys('x');
    t.expect(['hello worl']);
    t.sendKeys('u');
    return t.expect(['hello world']);
  });

  it('pastes', function() {
    let t = new TestCase([ 'hello world' ]);
    t.sendKeys('wv$y');
    t.sendKeys('P');
    t.expect([ 'hello worlworldd' ]);
    t.sendKeys('u');
    return t.expect(['hello world']);
  });

  return it('changes', function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('vec');
    t.sendKeys('hi');
    t.sendKey('esc');
    t.expect(['hi world']);
    t.sendKeys('u');
    return t.expect(['hello world']);
  });
});

