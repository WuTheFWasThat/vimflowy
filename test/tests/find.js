/* globals describe, it */
import TestCase from '../testcase';

describe('find', function() {
  it('works in basic cases', function() {
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
    return t.expect(['PeterPider licked a peck of pickled pepers']);
  });

  it('works backwards in basic cases', function() {
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
    return t.expect(['Peeter Piper plucked a pack of pickled pepers']);
  });

  it('works in edge cases', function() {
    let t = new TestCase(['edge case']);
    t.sendKeys('fsx');
    t.expect(['edge cae']);
    t.sendKeys('fex');
    t.expect(['edge ca']);
    t.sendKeys('fex');
    t.expect(['edge c']);

    t = new TestCase(['edge case']);
    t.sendKeys('2tex');
    t.expect(['edge cae']);
    t.sendKeys('htex');
    return t.expect(['edge ce']);
  });

  it('works in edge cases backwards', function() {
    let t = new TestCase(['edge case']);
    t.sendKeys('$Fdx');
    t.expect(['ege case']);
    t.sendKeys('Fex');
    t.expect(['ge case']);
    t.sendKeys('Fex');
    t.expect(['e case']);

    t = new TestCase(['edge case']);
    t.sendKeys('$2Tex');
    t.expect(['ege case']);
    t.sendKeys('Tex');
    t.expect(['ee case']);
    t.sendKeys('hTfx');
    return t.expect(['e case']);
  });

  return it('works with delete', function() {
    let t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('d2fa');
    t.expect(['wdf']);

    t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('d2ta');
    t.expect(['awdf']);

    t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('$d2Fa');
    t.expect(['awdf f']);

    t = new TestCase(['awdf awdf awdf']);
    t.sendKeys('$d2Ta');
    return t.expect(['awdf af']);
  });
});
