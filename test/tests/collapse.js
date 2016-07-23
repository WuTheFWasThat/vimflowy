/* globals describe, it */
import TestCase from '../testcase';

describe('collapse', () =>
  it('works in basic case', async function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    t.sendKeys('z');
    t.expect([
      { text: 'first', collapsed: true, children: [
        'second'
      ] },
      'third'
    ]);
    t.sendKeys('jx');
    t.expect([
      { text: 'first', collapsed: true, children: [
        'second'
      ] },
      'hird'
    ]);
    t.sendKeys('uu');
    t.expect([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    await t.done();
  })
);
