/* globals describe, it */
import TestCase from '../testcase';
import { RegisterTypes } from '../../src/assets/js/register';

describe('enter', function() {
  it('works in basic case', async function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('hello');
    t.sendKey('enter');
    t.sendKeys('world');
    t.sendKey('esc');
    t.expect(['hello', 'world']);
    await t.done();
  });

  it('works with tabbing', async function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('hello');
    t.sendKey('enter');
    t.sendKeys('world');
    t.sendKey('tab');
    t.sendKey('esc');
    t.expect([
      { text: 'hello', children: [
        'world',
      ] },
    ]);
    t.sendKey('u');
    t.sendKey('u');
    t.sendKey('u');
    t.expect(['']);
    t.sendKey('ctrl+r');
    t.sendKey('ctrl+r');
    t.sendKey('ctrl+r');
    t.expect([
      { text: 'hello', children: [
        'world',
      ] },
    ]);
    t.sendKeys('a of');
    t.sendKey('shift+tab');
    t.sendKeys(' goo');
    t.sendKey('esc');
    t.expect(['hello', 'world of goo']);
    await t.done();
  });

  it('does not mess up registers', async function() {
    let t = new TestCase(['']);
    t.setRegister({type: RegisterTypes.CHARS, saved: 'unchanged'});
    t.sendKey('i');
    t.sendKeys('helloworld');
    for (let i = 0; i < 5; i++) {
      t.sendKey('left');
    }
    t.sendKey('enter');
    t.sendKey('esc');
    t.expect(['hello', 'world']);
    t.expectRegister({type: RegisterTypes.CHARS, saved: 'unchanged'});
    await t.done();
  });

  it('works at the end of a line', async function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('hello');
    t.sendKey('enter');
    t.sendKey('esc');
    t.expect(['hello', '']);
    t.sendKey('u');
    t.expect(['hello']);
    t.sendKey('u');
    t.expect(['']);
    await t.done();
  });

  it('works at the beginning of a line', async function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKey('enter');
    t.sendKeys('hello');
    t.sendKey('esc');
    t.expect(['', 'hello']);
    t.sendKey('u');
    t.expect(['', '']);
    t.sendKey('u');
    t.expect(['']);
    await t.done();
  });

  it('works on lines with children', async function() {
    let t = new TestCase(['']);
    t.sendKey('i');
    t.sendKeys('helloworld');
    t.sendKey('enter');
    t.sendKeys('of goo');
    t.sendKey('esc');
    t.sendKey('tab');
    t.expect([
      { text: 'helloworld', children: [
        'of goo',
      ] },
    ]);
    t.sendKey('up');
    t.sendKey('I');
    for (let i = 0; i < 5; i++) {
      t.sendKey('right');
    }
    t.sendKey('enter');
    t.sendKey('esc');
    t.expect([
      'hello',
      { text: 'world', children: [
        'of goo',
      ] },
    ]);
    await t.done();
  });

  it('preserves identity at the end of a line', async function() {
    let t = new TestCase([
      { text: 'hey', id: 1 },
      'you',
      { clone: 1 },
    ]);
    t.sendKey('A');
    t.sendKey('enter');
    t.sendKeys('i like');
    t.expect([
      { text: 'hey', id: 1 },
      'i like',
      'you',
      { clone: 1 },
    ]);
    await t.done();
  });

  it('doesnt preserve identity in the middle of a line', async function() {
    let t = new TestCase([
      { text: 'hey', id: 1 },
      'you',
      { clone: 1 },
    ]);
    t.sendKey('$');
    t.sendKey('i');
    t.sendKey('enter');
    t.sendKeys('ya');
    t.expect([
      'he',
      { text: 'yay', id: 1 },
      'you',
      { clone: 1 },
    ]);
    await t.done();
  });

  it('handles case with children at end of line', async function() {
    let t = new TestCase([
      { text: 'hey', id: 1, children: [
        'like',
      ] },
      'you',
      { clone: 1 },
    ]);
    t.sendKey('A');
    t.sendKey('enter');
    t.sendKeys('i');
    t.expect([
      { text: 'hey', id: 1, children: [
        'i',
        'like',
      ] },
      'you',
      { clone: 1 },
    ]);
    await t.done();
  });

  it('handles collapsed case at end of line', async function() {
    let t = new TestCase([
      { text: 'hey', id: 1, collapsed: true, children: [
        'like',
      ] },
      'you',
      { clone: 1 },
    ]);
    t.sendKey('A');
    t.sendKey('enter');
    t.sendKeys('i');
    t.expect([
      { text: 'hey', id: 1, collapsed: true, children: [
        'like',
      ] },
      'i',
      'you',
      { clone: 1 },
    ]);
    await t.done();
  });

  it('when using o on a blank bullet, collapses parent', async function() {
    let t = new TestCase([
      { text: 'hey', children: [
        'you',
      ] },
    ]);
    t.sendKey('j');
    t.sendKey('enter');
    t.sendKeys('ook');
    t.sendKey('esc');
    t.expect([
      { text: 'hey', children: [
        { text: 'you', collapsed: true, children: [
          'ok',
        ] },
      ] },
    ]);
    t.sendKey('u');
    t.expect([
      { text: 'hey', children: [
        'you',
      ] },
    ]);
    await t.done();
  });
});
