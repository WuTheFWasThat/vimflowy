/* globals describe, it */
import TestCase from '../testcase';

let joinKey = 'J';

describe('join', function() {
  it('works in basic case', function() {
    let t = new TestCase(['ab', 'cd']);
    t.sendKeys(joinKey);
    t.expect(['ab cd']);
    t.sendKeys('x');
    return t.expect(['abcd']);
  });

  it('works with delimiter already there', function() {
    let t = new TestCase(['ab', ' cd']);
    t.sendKeys(joinKey);
    t.expect(['ab cd']);
    t.sendKeys('x');
    return t.expect(['abcd']);
  });

  it('works with child', function() {
    let t = new TestCase([
      { text: 'ab', children: [
        'cd'
      ] }
    ]);
    t.sendKeys(joinKey);
    t.expect(['ab cd']);
    t.sendKeys('x');
    return t.expect(['abcd']);
  });

  it('works where second line has child', function() {
    let t = new TestCase([
      'ab',
      { text: 'cd', children: [
        'ef',
        'gh'
      ] }
    ]);
    t.sendKeys(joinKey);
    t.expect([
      { text: 'ab cd', children: [
        'ef',
        'gh'
      ] },
    ]);
    t.sendKeys('x');
    return t.expect([
      { text: 'abcd', children: [
        'ef',
        'gh'
      ] },
    ]);
  });

  it('is undo and redo-able', function() {
    let t = new TestCase([
      'ab',
      { text: 'cd', children: [
        'ef'
      ] }
    ]);
    t.sendKeys(joinKey);
    t.expect([
      { text: 'ab cd', children: [
        'ef'
      ] },
    ]);
    t.sendKeys('x');
    t.expect([
      { text: 'abcd', children: [
        'ef'
      ] },
    ]);
    t.sendKeys('uu');
    t.expect([
      'ab',
      { text: 'cd', children: [
        'ef'
      ] },
    ]);
    t.sendKey('ctrl+r');
    return t.expect([
      { text: 'ab cd', children: [
        'ef'
      ] },
    ]);
  });

  it('works when second row is empty', function() {
    let t = new TestCase(['empty', '']);
    t.sendKeys('J');
    return t.expect(['empty']);
  });

  return it('doesnt affect registers', function() {
    let t = new TestCase(['af', 'as', 'df']);
    t.sendKeys('dd');
    t.expect(['as', 'df']);
    t.sendKeys('J');
    t.expect(['as df']);
    t.sendKeys('p');
    return t.expect(['as df', 'af']);
  });
});
