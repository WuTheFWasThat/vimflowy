/* globals describe, it */
import TestCase from '../testcase';

describe('repeat', function() {

  it('works with insertion of text', function() {
    let t = new TestCase(['']);
    t.sendKeys('....');
    t.expect(['']);
    t.sendKeys('irainbow');
    t.sendKey('esc');
    t.sendKey('.');
    t.expect(['rainborainboww']);
    t.sendKeys('x...');
    return t.expect(['rainborain']);
  });

  it('works with deletion + motion', function() {
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
    return t.expect(['xvxr xhx xerooxerox']);
  });

  it('works with change (c)', function() {
    let t = new TestCase(['vim is great']);
    t.sendKeys('ceblah');
    t.sendKey('esc');
    t.sendKeys('w.w.');
    return t.expect(['blah blah blah']);
  });

  return it('works with replace', function() {
    let t = new TestCase(['obladi oblada']);
    t.sendKeys('eroehl.');
    return t.expect(['oblado oblado']);
  });
});


describe('tricky cases for repeat', function() {
  it('test repeating x on empty row', function() {
    let t = new TestCase(['empty', '']);
    t.sendKeys('ru');
    t.expect(['umpty', '']);
    t.sendKeys('jxk.');
    return t.expect(['mpty', '']);
  });

  it('repeat of change', function() {
    let t = new TestCase([
      'oh say can you see',
      'and the home of the brave'
    ]);
    t.sendKeys('ceme');
    t.sendKey('esc');
    t.expect([
      'me say can you see',
      'and the home of the brave'
    ]);
    t.sendKeys('j$b.');
    return t.expect([
      'me say can you see',
      'and the home of the me'
    ]);
  });

  it('repeat of paste, edge case with empty line', function() {
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
    return t.expect(['wordword']);
  });

  it('works with visual mode', function() {
    let t = new TestCase([ '1234567' ]);
    t.sendKeys('vllx');
    t.expect([ '4567' ]);
    t.sendKeys('.');
    return t.expect([ '7' ]);
  });

  return it('doesnt repeat visual mode yank', function() {
    let t = new TestCase([ '1234' ]);
    t.sendKeys('xvly');
    t.expect([ '234' ]);
    t.sendKeys('.');
    return t.expect([ '24' ]);
  });
});

