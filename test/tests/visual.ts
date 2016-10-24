/* globals describe, it */
import TestCase from '../testcase';

describe('visual mode', function() {
  it('works with basic motions', async function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('vwx');
    t.expect(['orld']);
    await t.done();

    t = new TestCase(['hello world']);
    t.sendKeys('vex');
    t.expect([' world']);
    await t.done();

    t = new TestCase(['hello world']);
    t.sendKeys('v$x');
    t.expect(['']);
    await t.done();

    t = new TestCase(['hello world']);
    t.sendKeys('wv3lx');
    t.expect(['hello d']);
    await t.done();
  });

  it('keeps cursor after canceling', async function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('vw');
    t.sendKey('esc');
    t.sendKeys('x');
    t.expect(['hello orld']);
    await t.done();
  });

  it('allows cursor swap', async function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('wv3lo3hx');
    t.expect(['held']);
    t.sendKeys('u');
    t.expect(['hello world']);
    await t.done();
  });

  it('moves cursor back if needed', async function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('v$');
    t.sendKey('esc');
    t.sendKeys('x');
    t.expect(['hello worl']);
    t.sendKeys('u');
    t.expect(['hello world']);
    await t.done();
  });

  it('pastes', async function() {
    let t = new TestCase([ 'hello world' ]);
    t.sendKeys('wv$y');
    t.sendKeys('P');
    t.expect([ 'hello worlworldd' ]);
    t.sendKeys('u');
    t.expect(['hello world']);
    await t.done();
  });

  it('changes', async function() {
    let t = new TestCase(['hello world']);
    t.sendKeys('vec');
    t.sendKeys('hi');
    t.sendKey('esc');
    t.expect(['hi world']);
    t.sendKeys('u');
    t.expect(['hello world']);
    await t.done();
  });
});

