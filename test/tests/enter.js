/* globals describe, it */
import TestCase from '../testcase';
import Register from '../../assets/js/register.coffee';

describe('enter', function() {
  it('works in basic case', function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('hello');
    t.sendKey('enter');
    t.sendKeys('world');
    t.sendKey('esc');
    t.expect(['hello', 'world']);
    t.sendKey('u');
    return t.expect(['']);
  });

  it('works with tabbing', function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('hello');
    t.sendKey('enter');
    t.sendKeys('world');
    t.sendKey('tab');
    t.sendKey('esc');
    t.expect([
      { text: 'hello', children: [
        'world'
      ] }
    ]);
    t.sendKey('u');
    t.expect(['']);
    t.sendKey('ctrl+r');
    t.expect([
      { text: 'hello', children: [
        'world'
      ] }
    ]);
    t.sendKeys('a of');
    t.sendKey('shift+tab');
    t.sendKeys(' goo');
    t.sendKey('esc');
    return t.expect(['hello', 'world of goo']);
  });

  it('does not mess up registers', function() {
    let t = new TestCase(['']);
    t.setRegister({type: Register.TYPES.CHARS, saved: 'unchanged'});
    t.sendKey('i');
    t.sendKeys('helloworld');
    for (let i = 0; i < 5; i++) {
      t.sendKey('left');
    }
    t.sendKey('enter');
    t.sendKey('esc');
    t.expect(['hello', 'world']);
    return t.expectRegister({type: Register.TYPES.CHARS, saved: 'unchanged'});
  });

  it('works at the end of a line', function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('hello');
    t.sendKey('enter');
    t.sendKey('esc');
    t.expect(['hello', '']);
    t.sendKey('u');
    return t.expect(['']);
  });

  it('works at the beginning of a line', function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKey('enter');
    t.sendKeys('hello');
    t.sendKey('esc');
    t.expect(['', 'hello']);
    t.sendKey('u');
    return t.expect(['']);
  });

  it('works on lines with children', function() {
    let t=  new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('helloworld');
    t.sendKey('enter');
    t.sendKeys('of goo');
    t.sendKey('esc');
    t.sendKey('tab');
    t.expect([
      { text: 'helloworld', children: [
        'of goo'
      ] }
    ]);
    t.sendKey('up');
    t.sendKey('I');
    for (let i = 0; i < 5; i++) {
      t.sendKey('right');
    }
    t.sendKey('enter');
    t.sendKey('esc');
    return t.expect([
      'hello',
      { text: 'world', children: [
        'of goo'
      ] }
    ]);
  });

  it('preserves identity at the end of a line', function() {
    let t = new TestCase([
      { text: 'hey', id: 1 },
      'you',
      { clone: 1 }
    ]);
    t.sendKey('A');
    t.sendKey('enter');
    t.sendKeys('i like');
    return t.expect([
      { text: 'hey', id: 1 },
      'i like',
      'you',
      { clone: 1 }
    ]);
  });

  it('doesnt preserve identity in the middle of a line', function() {
    let t = new TestCase([
      { text: 'hey', id: 1 },
      'you',
      { clone: 1 }
    ]);
    t.sendKey('$');
    t.sendKey('i');
    t.sendKey('enter');
    t.sendKeys('ya');
    return t.expect([
      'he',
      { text: 'yay', id: 1 },
      'you',
      { clone: 1 }
    ]);
  });

  it('handles case with children at end of line', function() {
    let t = new TestCase([
      { text: 'hey', id: 1, children: [
        'like'
      ] },
      'you',
      { clone: 1 }
    ]);
    t.sendKey('A');
    t.sendKey('enter');
    t.sendKeys('i');
    return t.expect([
      { text: 'hey', id: 1, children: [
        'i',
        'like'
      ] },
      'you',
      { clone: 1 }
    ]);
  });

  it('handles collapsed case at end of line', function() {
    let t = new TestCase([
      { text: 'hey', id: 1, collapsed: true, children: [
        'like'
      ] },
      'you',
      { clone: 1 }
    ]);
    t.sendKey('A');
    t.sendKey('enter');
    t.sendKeys('i');
    return t.expect([
      { text: 'hey', id: 1, collapsed: true, children: [
        'like'
      ] },
      'i',
      'you',
      { clone: 1 }
    ]);
  });

  return it('when using o on a blank bullet, collapses parent', function() {
    let t = new TestCase([
      { text: 'hey', children: [
        'you'
      ] }
    ]);
    t.sendKey('j');
    t.sendKey('enter');
    t.sendKeys('ook');
    t.sendKey('esc');
    t.expect([
      { text: 'hey', children: [
        { text: 'you', collapsed: true, children: [
          'ok'
        ] }
      ] }
    ]);
    t.sendKey('u');
    return t.expect([
      { text: 'hey', children: [
        'you'
      ] }
    ]);
  });
});
