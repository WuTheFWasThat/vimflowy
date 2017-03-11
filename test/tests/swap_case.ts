/* globals describe, it */
import TestCase from '../testcase';

describe('swapping case', function() {
  it('should swap case at cursor and moving cursor to the right', async function() {
    const t = new TestCase(['oo']);
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
    const t = new TestCase(['oo']);
    t.sendKeys('$~');
    t.expect(['oO']);
    t.expectCursor(1,1);

    t.sendKeys('~');
    t.expect(['oo']);
    t.expectCursor(1,1);

    await t.done();
  });

  it('should swap case in visual mode', async function() {
    const t = new TestCase(['swapCaseHere']);
    t.sendKeys('0llvlll~');
    t.expect(['swAPcAseHere']);
    t.expectCursor(1, 2);

    t.sendKeys('v0~');
    t.expect(['SWaPcAseHere']);
    t.expectCursor(1, 0);

    await t.done();
  });

  it('should undo case swapping', async function() {
    const t = new TestCase(['swapCaseHere']);
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

  it('should swap case for multiple selected lines', async function() {
    const t = new TestCase(['swap', 'case', 'here']);
    t.sendKeys('0Vj~');
    t.expect(['SWAP', 'CASE', 'here']);
    t.expectCursor(2, 0);

    await t.done();
  });

  it('should swap case for multiple selected nodes, without children', async function () {
    const t = new TestCase([
      {
        text: 'swap',
        children: ['case']
      },
      'here',
      'not here'
    ]);
    t.sendKeys('0Vjj~');
    t.expect([
      {
        text: 'SWAP',
        children: ['case']
      },
      'HERE',
      'not here'
    ]);
    t.expectCursor(3, 0);

    await t.done();
  });

  it('should undo multiline case swapping', async function() {
    const t = new TestCase(['swap', 'case']);
    t.sendKeys('0V~');
    t.expect(['SWAP', 'case']);
    t.expectCursor(1, 0);

    t.sendKeys('u');
    t.expect(['swap', 'case']);
    t.expectCursor(1, 0);

    await t.done();
  })
});
