/* globals describe, it */
import TestCase from '../testcase';
let siblingDownKey = '}';
let siblingUpKey = '{';

describe('visual line mode', function() {
  it('delete works in basic case', async function() {
    let t = new TestCase([ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]);
    t.sendKeys('Vjx');
    t.expect([ 'i', 'am', 'a', 'test', 'case' ]);
    t.sendKeys('u');
    t.expect([ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]);
    await t.done();
  });

  it('change works in basic case', async function() {
    let t = new TestCase([ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]);
    t.sendKeys('GVkc');
    t.expect([ 'hello', 'world', 'i', 'am', 'a', '']);
    t.sendKeys('confused soul');
    t.expect([ 'hello', 'world', 'i', 'am', 'a', 'confused soul' ]);
    t.sendKey('esc');
    t.sendKeys('u');
    t.expect([ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]);
    await t.done();
  });

  it('allows cursor switch', async function() {
    let t = new TestCase([ 'hello', 'world', 'i', 'am', 'a', 'test', 'case' ]);
    t.sendKeys('jjjx');
    t.expect([ 'hello', 'world', 'i', 'm', 'a', 'test', 'case' ]);
    t.sendKeys('Vjjokkd');
    t.expect([ 'hello', 'case' ]);
    t.sendKeys('u');
    t.expect([ 'hello', 'world', 'i', 'm', 'a', 'test', 'case' ]);
    t.sendKey('ctrl+r');
    t.expect([ 'hello', 'case' ]);
    await t.done();
  });

  it('works with repeat', async function() {
    let t = new TestCase([ '1', '2', '3', '4', '5', '6', '7' ]);
    t.sendKeys('Vjjx');
    t.expect([ '4', '5', '6', '7' ]);
    t.sendKeys('.');
    t.expect([ '7' ]);
    await t.done();
  });

  it('doesnt save on yank', async function() {
    let t = new TestCase([ '1', '2' ]);
    t.sendKeys('xjVy');
    t.expect([ '', '2' ]);
    t.sendKeys('.'); // this is the x, not the y
    t.expect([ '', '' ]);
    await t.done();
  });

  it('works with deleting children', async function() {
    let t = new TestCase([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys(['V', siblingDownKey, 'x']);
    t.expect([
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys('p');
    t.expect([
      { text: 'nest 3', children: [
        { text: 'nest', children: [
          'egg',
        ] },
        { text: 'nest 2', children: [
          'egg 2',
        ] },
        'egg 3',
      ] },
    ]);
    // ends up on row 2
    t.sendKeys(['V', siblingDownKey, siblingDownKey, 'd', 'p']);
    t.expect([
      'nest 3',
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
      ] },
      'egg 3',
    ]);
    // ends up on row 2
    t.sendKeys('x');
    t.expect([
      'nest 3',
      { text: 'est', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
      ] },
      'egg 3',
    ]);
    t.sendKeys('u');
    t.expect([
      'nest 3',
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
      ] },
      'egg 3',
    ]);
    t.sendKeys('u');
    t.expect([ 'nest 3' ]);
    t.sendKeys('u');
    t.expect([
      { text: 'nest 3', children: [
        { text: 'nest', children: [
          'egg',
        ] },
        { text: 'nest 2', children: [
          'egg 2',
        ] },
        'egg 3',
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    await t.done();
  });

  it('works with indent', async function() {
    let t = new TestCase([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    // does nothing when can't indent
    t.sendKeys(['j', 'V', '>']);
    t.expect([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    // now can indent
    t.sendKeys(['j', 'V', siblingDownKey, '>']);
    t.expect([
      { text: 'nest', children: [
        'egg',
        { text: 'nest 2', children: [
          'egg 2',
          'egg 2 2',
        ] },
        { text: 'nest 3', children: [
          'egg 3',
        ] },
      ] },
    ]);
    // does nothing again
    t.sendKeys([siblingUpKey]);
    t.sendKeys('jV>');
    t.expect([
      { text: 'nest', children: [
        'egg',
        { text: 'nest 2', children: [
          'egg 2',
          'egg 2 2',
        ] },
        { text: 'nest 3', children: [
          'egg 3',
        ] },
      ] },
    ]);
    // unindent
    t.sendKeys('V<');
    t.expect([
      { text: 'nest', children: [
        'egg',
        { text: 'nest 2', children: [
          'egg 2 2',
        ] },
        'egg 2',
        { text: 'nest 3', children: [
          'egg 3',
        ] },
      ] },
    ]);
    // undo ignores things that didn't happen
    t.sendKeys('u');
    t.expect([
      { text: 'nest', children: [
        'egg',
        { text: 'nest 2', children: [
          'egg 2',
          'egg 2 2',
        ] },
        { text: 'nest 3', children: [
          'egg 3',
        ] },
      ] },
    ]);
    t.sendKeys('u');
    t.expect([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    await t.done();
  });

  it('works when cursor/anchor are ancestors of each other', async function() {
    let t = new TestCase([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys('Vjd');
    t.expect([
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys('jVkd');
    t.expect([
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    await t.done();
  });

  it('has LCA behavior', async function() {
    let t = new TestCase([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys('jVjd');
    t.expect([
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    await t.done();

    t = new TestCase([
      { text: 'nest', children: [
        'egg',
      ] },
      { text: 'nest 2', children: [
        'egg 2',
        'egg 2 2',
      ] },
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    t.sendKeys('jVjjd');
    t.expect([
      { text: 'nest 3', children: [
        'egg 3',
      ] },
    ]);
    await t.done();

    t = new TestCase([
      { text: 'this case', children: [
        { text: 'broke in ', children: [
          'real',
          'life',
        ] },
        'whoops!',
      ] },
    ]);
    t.sendKeys('jjjVkkd');
    t.expect([
      { text: 'this case', children: [
        'whoops!',
      ] },
    ]);
    await t.done();
  });

  it('works with go to end of document', async function() {
    let t = new TestCase([
      'yay',
      { text: 'hip', children: [
        { text: 'hop', children: [
          'hoop',
        ] },
      ] },
      'hooray!',
    ]);
    t.sendKeys('VGd');
    t.expect([ '' ]);
    t.sendKeys('u');
    t.expect([
      'yay',
      { text: 'hip', children: [
        { text: 'hop', children: [
          'hoop',
        ] },
      ] },
      'hooray!',
    ]);
    await t.done();
  });

  it('yank clone works', async function() {
    let t = new TestCase([
      'yay',
      'woo',
      { text: 'yes', children: [
        'hooray!',
      ] },
    ]);
    t.sendKeys('Vj');
    t.sendKeys('Y');
    t.sendKeys('jp');
    t.expect([
      { text: 'yay', id: 1 },
      { text: 'woo', id: 2 },
      { text: 'yes', children: [
        { clone: 1 },
        { clone: 2 },
        'hooray!',
      ] },
    ]);
    await t.done();
  });

  it('visual line join works', async function() {
    let t = new TestCase([
      'yay',
      'woo',
      { text: 'hip', children: [
        { text: 'hop', collapsed: true, children: [
          'hoop',
        ] },
      ] },
      'hooray!',
    ]);
    // some rows are folded, can't join
    t.sendKeys('Vjj');
    t.sendKeys('J');
    t.expect([
      'yay',
      'woo',
      { text: 'hip', children: [
        { text: 'hop', collapsed: true, children: [
          'hoop',
        ] },
      ] },
      'hooray!',
    ]);
    await t.done();
    // now can join
    t = new TestCase([
      'yay',
      'woo',
      { text: 'hip', children: [
        { text: 'hop', children: [
          'hoop',
        ] },
      ] },
      'hooray!',
    ]);
    t.sendKeys('Vjj');
    t.sendKeys('J');
    t.expect([
      'yay\nwoo\nhip\nhop\nhoop',
      'hooray!',
    ]);
    await t.done();
  });
});
