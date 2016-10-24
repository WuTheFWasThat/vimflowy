/* globals describe, it */
import TestCase from '../testcase';

describe('repeat', function() {

  it('works with insertion of text', async function() {
    let t = new TestCase(['']);
    t.sendKeys('....');
    t.expect(['']);
    t.sendKeys('irainbow');
    t.sendKey('esc');
    t.sendKey('.');
    t.expect(['rainborainboww']);
    t.sendKeys('x...');
    t.expect(['rainborain']);
    await t.done();
  });

  it('works with deletion + motion', async function() {
    let t = new TestCase(['the quick brown fox   jumped   over the lazy dog']);
    t.sendKeys('dw');
    t.expect(['quick brown fox   jumped   over the lazy dog']);
    t.sendKeys('..');
    t.expect(['fox   jumped   over the lazy dog']);
    t.sendKeys('u.');
    t.expect(['fox   jumped   over the lazy dog']);
    t.sendKeys('dy'); // nonsense
    t.expect(['fox   jumped   over the lazy dog']);
    t.sendKeys('..');
    t.expect(['over the lazy dog']);
    t.sendKeys('rxll.w.e.$.');
    t.expect(['xvxr xhx lazy dox']);
    t.sendKeys('cbxero');
    t.sendKey('esc');
    t.expect(['xvxr xhx lazy xerox']);
    t.sendKeys('b.');
    t.expect(['xvxr xhx xeroxerox']);
    t.sendKeys('.');
    t.expect(['xvxr xhx xerooxerox']);
    await t.done();
  });

  it('works with change (c)', async function() {
    let t = new TestCase(['vim is great']);
    t.sendKeys('ceblah');
    t.sendKey('esc');
    t.sendKeys('w.w.');
    t.expect(['blah blah blah']);
    await t.done();
  });

  it('works with replace', async function() {
    let t = new TestCase(['obladi oblada']);
    t.sendKeys('eroehl.');
    t.expect(['oblado oblado']);
    await t.done();
  });
});


describe('tricky cases for repeat', function() {
  it('test repeating x on empty row', async function() {
    let t = new TestCase(['empty', '']);
    t.sendKeys('ru');
    t.expect(['umpty', '']);
    t.sendKeys('jxk.');
    t.expect(['mpty', '']);
    await t.done();
  });

  it('repeat of change', async function() {
    let t = new TestCase([
      'oh say can you see',
      'and the home of the brave',
    ]);
    t.sendKeys('ceme');
    t.sendKey('esc');
    t.expect([
      'me say can you see',
      'and the home of the brave',
    ]);
    t.sendKeys('j$b.');
    t.expect([
      'me say can you see',
      'and the home of the me',
    ]);
    await t.done();
  });

  it('repeat of paste, edge case with empty line', async function() {
    let t = new TestCase(['word']);
    t.sendKeys('de');
    t.expect(['']);
    t.sendKeys('p');
    t.expect(['word']);
    t.sendKeys('u');
    t.expect(['']);
    // repeat still knows what to do
    t.sendKeys('.');
    t.expect(['word']);
    t.sendKeys('.');
    t.expect(['wordword']);
    await t.done();
  });

  it('works with visual mode', async function() {
    let t = new TestCase([ '1234567' ]);
    t.sendKeys('vllx');
    t.expect([ '4567' ]);
    t.sendKeys('.');
    t.expect([ '7' ]);
    await t.done();
  });

  it('doesnt repeat visual mode yank', async function() {
    let t = new TestCase([ '1234' ]);
    t.sendKeys('xvly');
    t.expect([ '234' ]);
    t.sendKeys('.');
    t.expect([ '24' ]);
    await t.done();
  });
});

