/* globals describe, it */
import TestCase from '../testcase';

describe('find', function() {
  it('works in basic cases', async function() {
    let t = new TestCase(['Peter Piper picked a peck of pickled peppers']);
    t.sendKeys('fprd');
    t.expect(['Peter Pider picked a peck of pickled peppers']);
    t.sendKeys('fprl');
    t.expect(['Peter Pider licked a peck of pickled peppers']);
    t.sendKeys('5fpx');
    t.expect(['Peter Pider licked a peck of pickled pepers']);
    t.sendKeys('u');
    t.expect(['Peter Pider licked a peck of pickled peppers']);
    t.sendKeys('5fpx');
    t.expect(['Peter Pider licked a peck of pickled pepers']);
    t.sendKeys('0tPx');
    t.expect(['PeterPider licked a peck of pickled pepers']);
    await t.done();
  });

  it('works backwards in basic cases', async function() {
    let t = new TestCase(['Peter Piper picked a peck of pickled peppers']);
    t.sendKeys('$Fpx');
    t.expect(['Peter Piper picked a peck of pickled pepers']);
    t.sendKeys('3FpTpra');
    t.expect(['Peter Piper picked a pack of pickled pepers']);
    t.sendKeys('TpruFpal');
    t.sendKey('esc');
    t.expect(['Peter Piper plucked a pack of pickled pepers']);
    t.sendKeys('2TPae');
    t.sendKey('esc');
    t.expect(['Peeter Piper plucked a pack of pickled pepers']);
    await t.done();
  });

  it('works in edge cases', async function() {
    let t = new TestCase(['edge case']);
    t.sendKeys('fsx');
    t.expect(['edge cae']);
    t.sendKeys('fex');
    t.expect(['edge ca']);
    t.sendKeys('fex');
    t.expect(['edge c']);
    await t.done();

    t = new TestCase(['edge case']);
    t.sendKeys('2tex');
    t.expect(['edge cae']);
    t.sendKeys('htex');
    t.expect(['edge ce']);
    await t.done();
  });

  it('works in edge cases backwards', async function() {
    let t = new TestCase(['edge case']);
    t.sendKeys('$Fdx');
    t.expect(['ege case']);
    t.sendKeys('Fex');
    t.expect(['ge case']);
    t.sendKeys('Fex');
    t.expect(['e case']);
    await t.done();

    t = new TestCase(['edge case']);
    t.sendKeys('$2Tex');
    t.expect(['ege case']);
    t.sendKeys('Tex');
    t.expect(['ee case']);
    t.sendKeys('hTfx');
    t.expect(['e case']);
    await t.done();
  });

  it('works with delete', async function() {
    let t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('d2fa');
    t.expect(['wdf']);
    await t.done();

    t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('d2ta');
    t.expect(['awdf']);
    await t.done();

    t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('$d2Fa');
    t.expect(['awdf f']);
    await t.done();

    t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('$d2Ta');
    t.expect(['awdf af']);
    await t.done();
  });
});
