/* globals describe, it */
import TestCase from '../testcase';

describe('collapse', () => {
  it('works in basic case', async function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second',
      ] },
      'third',
    ]);
    t.sendKeys('z');
    t.expect([
      { text: 'first', collapsed: true, children: [
        'second',
      ] },
      'third',
    ]);
    t.sendKeys('jx');
    t.expect([
      { text: 'first', collapsed: true, children: [
        'second',
      ] },
      'hird',
    ]);
    t.sendKeys('uu');
    t.expect([
      { text: 'first', children: [
        'second',
      ] },
      'third',
    ]);
    await t.done();
  });

  it('open and close work in insert mode', async function() {
    let t = new TestCase([
      { text: 'first', collapsed: true, children: [
        'second',
      ] },
    ]);
    t.sendKeys('if-');
    t.sendKey('meta+down');
    t.expect([
      { text: 'f-first', children: [
        'second',
      ] },
    ]);
    t.sendKey('meta+down');
    t.expect([
      { text: 'f-first', children: [
        'second',
      ] },
    ]);
    t.sendKey('meta+up');
    t.expect([
      { text: 'f-first', collapsed: true, children: [
        'second',
      ] },
    ]);
    t.sendKey('meta+up');
    t.expect([
      { text: 'f-first', collapsed: true, children: [
        'second',
      ] },
    ]);
    t.sendKeys('f-');
    t.expect([
      { text: 'f-f-first', collapsed: true, children: [
        'second',
      ] },
    ]);
    t.sendKey('ctrl+z');
    t.expect([
      { text: 'f-first', collapsed: true, children: [
        'second',
      ] },
    ]);
    t.sendKey('ctrl+z');
    t.expect([
      { text: 'f-first', children: [
        'second',
      ] },
    ]);
    t.sendKey('ctrl+z');
    t.expect([
      { text: 'f-first', collapsed: true, children: [
        'second',
      ] },
    ]);
    t.sendKey('ctrl+z');
    t.expect([
      { text: 'first', collapsed: true, children: [
        'second',
      ] },
    ]);
    await t.done();
  });
});
