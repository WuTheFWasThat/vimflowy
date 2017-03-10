/* globals describe, it */
import TestCase from '../testcase';

describe.only('swapping case', function() {
  it('should swap case at cursor and moving cursor to the right', async function() {
    let t = new TestCase(['oo']);
    t.sendKeys('0');
    t.sendKey('~');
    t.expect(['Oo']);
    t.expectCursor(1, 1);

    t.sendKeys('0');
    t.sendKey('~');
    t.expect(['oo']);
    t.expectCursor(1, 1);

    await t.done();
  });

  it('should not move cursor if swapping at the end of line', async function() {
    let t = new TestCase(['oo']);
    t.sendKeys('$~');
    t.expect(['oO']);
    t.expectCursor(1,1);

    t.sendKeys('~');
    t.expect(['oo']);
    t.expectCursor(1,1);

    await t.done();
  });

  it('should swap case in visual mode', async function() {
    let t = new TestCase(['swapCaseHere']);
    t.sendKeys('0llvlll~');
    t.expect(['swAPcAseHere']);
    t.expectCursor(1, 2);

    t.sendKeys('v0~');
    t.expect(['SWaPcAseHere']);
    t.expectCursor(1, 0);

    await t.done();
  });

  it('should undo case swapping', async function() {
    let t = new TestCase(['swapCaseHere']);
    t.sendKeys('0~');
    t.expect(['SwapCaseHere']);
    t.sendKeys('u');
    t.expect(['swapCaseHere']);

    t.sendKeys('llvll~');
    t.expect(['swAPcaseHere']);
    t.sendKeys('u');
    t.expect(['swapCaseHere']);

    await t.done();
  });
});
