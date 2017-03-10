/* globals describe, it */
import TestCase from '../testcase';
// import { RegisterTypes } from '../../src/assets/js/register';

describe.only('swapping case', function() {
  it('should swap case at cursor and moving cursor to the right', async function() {
    let t = new TestCase(['oo']);
    t.sendKeys('0');
    t.sendKey('~');
    t.expect(['Oo']);
    t.expectCursor(1, 1);
    await t.done();
  });

  it('should not move cursor if swapping at the end of line', async function() {
    let t = new TestCase(['oo']);
    t.sendKeys('$~');
    t.expect(['oO']);
    t.expectCursor(1,1);
    await t.done();
  })
});
