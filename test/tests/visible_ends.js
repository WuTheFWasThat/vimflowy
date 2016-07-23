/* globals describe, it */
import TestCase from '../testcase';

describe('go visible end/beginning', function() {
  it('take you to the first column', async function() {
    let t = new TestCase(['always to front']);
    t.sendKeys('$Gx');
    t.expect(['lways to front']);
    await t.done();

    t = new TestCase(['a', 'ab', 'abc']);
    t.sendKeys('$Gx');
    t.expect(['a', 'ab', 'bc']);
    await t.done();

    t = new TestCase(['always to front']);
    t.sendKeys('$ggx');
    t.expect(['lways to front']);
    await t.done();
  });

  it('basically works, at root', async function() {
    let t = new TestCase([
      'ab',
      { text: 'bc', children: [
        'cd'
      ] },
    ]);
    t.sendKeys('Gx');
    t.expect([
      'ab',
      { text: 'bc', children: [
        'd'
      ] },
    ]);
    t.sendKeys('ggx');
    t.expect([
      'b',
      { text: 'bc', children: [
        'd'
      ] },
    ]);
    await t.done();

    t = new TestCase(['a', 'ab', 'abc']);
    t.sendKeys('jj$x');
    t.expect(['a', 'ab', 'ab']);
    t.sendKeys('ggx');
    t.expect(['', 'ab', 'ab']);
    await t.done();
  });

  it('ignores collapsed children', async function() {
    let t = new TestCase([
      'ab',
      { text: 'bc', collapsed: true, children: [
        'cd'
      ] },
    ]);
    t.sendKeys('Gx');
    t.expect([
      'ab',
      { text: 'c', collapsed: true, children: [
        'cd'
      ] },
    ]);
    await t.done();
  });

  it('works zoomed in', async function() {
    let t = new TestCase([
      'ab',
      { text: 'bc', children: [
        'dc',
        'cd'
      ] },
      'de'
    ]);
    t.sendKeys('j]Gx');
    t.expect([
      'ab',
      { text: 'bc', children: [
        'dc',
        'd'
      ] },
      'de'
    ]);
    t.sendKeys('ggx');
    t.expect([
      'ab',
      { text: 'c', children: [
        'dc',
        'd'
      ] },
      'de'
    ]);
    await t.done();
  });

  it('works zoomed in to collapsed', async function() {
    let t = new TestCase([
      'ab',
      { text: 'bc', collapsed: true, children: [
        'dc',
        'cd'
      ] },
      'de'
    ]);
    t.sendKeys('j]Gx');
    t.expect([
      'ab',
      { text: 'bc', collapsed: true, children: [
        'dc',
        'd'
      ] },
      'de'
    ]);
    t.sendKeys('ggx');
    t.expect([
      'ab',
      { text: 'c', collapsed: true, children: [
        'dc',
        'd'
      ] },
      'de'
    ]);
    t.sendKeys('j]Gx');
    t.expect([
      'ab',
      { text: 'c', collapsed: true, children: [
        'c',
        'd'
      ] },
      'de'
    ]);
    t.sendKeys('ggx');
    t.expect([
      'ab',
      { text: 'c', collapsed: true, children: [
        '',
        'd'
      ] },
      'de'
    ]);
    await t.done();
  });
});
