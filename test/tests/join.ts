/* globals describe, it */
import TestCase from '../testcase';

let joinKey = 'J';

describe('join', function() {
  it('works in basic case', async function() {
    let t = new TestCase(['ab', 'cd']);
    t.sendKeys(joinKey);
    t.expect(['ab cd']);
    t.sendKeys('x');
    t.expect(['abcd']);
    await t.done();
  });

  it('works with delimiter already there', async function() {
    let t = new TestCase(['ab', ' cd']);
    t.sendKeys(joinKey);
    t.expect(['ab cd']);
    t.sendKeys('x');
    t.expect(['abcd']);
    await t.done();
  });

  it('works with child', async function() {
    let t = new TestCase([
      { text: 'ab', children: [
        'cd',
      ] },
    ]);
    t.sendKeys(joinKey);
    t.expect(['ab cd']);
    t.sendKeys('x');
    t.expect(['abcd']);
    await t.done();
  });

  it('works where second line has child', async function() {
    let t = new TestCase([
      'ab',
      { text: 'cd', children: [
        'ef',
        'gh',
      ] },
    ]);
    t.sendKeys(joinKey);
    t.expect([
      { text: 'ab cd', children: [
        'ef',
        'gh',
      ] },
    ]);
    t.sendKeys('x');
    t.expect([
      { text: 'abcd', children: [
        'ef',
        'gh',
      ] },
    ]);
    await t.done();
  });

  it('is undo and redo-able', async function() {
    let t = new TestCase([
      'ab',
      { text: 'cd', children: [
        'ef',
      ] },
    ]);
    t.sendKeys(joinKey);
    t.expect([
      { text: 'ab cd', children: [
        'ef',
      ] },
    ]);
    t.sendKeys('x');
    t.expect([
      { text: 'abcd', children: [
        'ef',
      ] },
    ]);
    t.sendKeys('uu');
    t.expect([
      'ab',
      { text: 'cd', children: [
        'ef',
      ] },
    ]);
    t.sendKey('ctrl+r');
    t.expect([
      { text: 'ab cd', children: [
        'ef',
      ] },
    ]);
    await t.done();
  });

  it('works when second row is empty', async function() {
    let t = new TestCase(['empty', '']);
    t.sendKeys('J');
    t.expect(['empty']);
    await t.done();
  });

  it('doesnt affect registers', async function() {
    let t = new TestCase(['af', 'as', 'df']);
    t.sendKeys('dd');
    t.expect(['as', 'df']);
    t.sendKeys('J');
    t.expect(['as df']);
    t.sendKeys('p');
    t.expect(['as df', 'af']);
    await t.done();
  });
});
