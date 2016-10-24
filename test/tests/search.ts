/* globals describe, it */
import TestCase from '../testcase';

describe('search', function() {
  it('works in basic cases', async function() {
    let t = new TestCase([
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(5);
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'blah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(4);
    await t.done();
  });

  it('can page down through menu results', async function() {
    let t = new TestCase([
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(5);
    t.sendKey('ctrl+j');
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'blah',
      'searchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(4);
    await t.done();

    t = new TestCase([
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(5);
    t.sendKey('ctrl+j');
    t.sendKey('ctrl+j');
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'blah',
      'searchblah',
      'blahsearchblah',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(4);
    await t.done();
  });

  it('delete works', async function() {
    let t = new TestCase([
      'blah',
      'blur',
    ]);
    t.sendKeys('/blurb');
    t.expectNumMenuResults(0);
    t.sendKey('backspace');
    t.expectNumMenuResults(1);
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'blah',
    ]);
    await t.done();

    t = new TestCase([
      'blah',
      'blur',
    ]);
    t.sendKeys('/blurb');
    t.expectNumMenuResults(0);
    t.sendKey('left');
    t.sendKey('delete');
    t.expectNumMenuResults(1);
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'blah',
    ]);
    await t.done();
  });

  it('can page up through menu results', async function() {
    let t = new TestCase([
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(5);
    t.sendKey('ctrl+k');
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      'blah',
    ]);
    t.sendKeys('/search');
    t.expectNumMenuResults(4);
    await t.done();
  });

  it('can be canceled', async function() {
    let t = new TestCase([
      'blah',
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    t.sendKeys('/search');
    t.sendKey('esc');
    t.sendKeys('dd');
    t.expect([
      'searchblah',
      'blahsearchblah',
      'search',
      'surch',
      { text: 'blahsearch', children: [
        'blah',
      ] },
      { text: 'blah', children: [
        'search',
      ] },
    ]);
    await t.done();
  });

  it('is case insensitive', async function() {
    let t = new TestCase([
      'case',
      'crease',
      'CASE',
    ]);
    t.sendKeys('/case');
    t.sendKey('ctrl+j');
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'case',
      'crease',
    ]);
    await t.done();
  });

  it('searches independently for words', async function() {
    let t = new TestCase([
      'broomball',
      'basketball',
      'basket of bread',
    ]);
    t.sendKeys('/bread basket');
    t.sendKey('enter');
    t.sendKeys('dd');
    t.expect([
      'broomball',
      'basketball',
    ]);
    await t.done();
  });

  it('moves the cursor to the searched for row', async function() {
    let t = new TestCase([
      { text: 'first', children: [
        { text: 'second', children: [
          'third',
        ] },
      ] },
    ]);
    t.sendKeys('jj]]]');
    t.expectViewRoot(3);
    t.sendKeys('/fir');
    t.sendKey('enter');
    t.expectViewRoot(1);
    await t.done();
  });
});
