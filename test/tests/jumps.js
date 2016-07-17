/* globals describe, it */
import TestCase from '../testcase';

let jumpPreviousKey = 'ctrl+o';
let jumpNextKey = 'ctrl+i';

describe('jumps', function() {
  it('basically works', function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);
    t.sendKeys(']');
    t.expectViewRoot(1);
    t.expectCursor(1, 0);

    t.sendKey(jumpPreviousKey);
    t.expectJumpIndex(0);
    t.expectViewRoot(0);
    // doesn't go past border
    t.sendKey(jumpPreviousKey);
    t.expectJumpIndex(0);
    t.expectViewRoot(0);

    t.sendKey(jumpNextKey);
    t.expectJumpIndex(1);
    t.expectViewRoot(1);
    // doesn't go past border
    t.sendKey(jumpNextKey);
    t.expectJumpIndex(1);
    t.expectViewRoot(1);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.sendKeys('dd');
    t.expect([
      'third'
    ]);
    t.sendKey(jumpNextKey); // fails
    t.expectViewRoot(0);
    t.sendKeys('p');
    t.expect([
      'third',
      { text: 'first', children: [
        'second'
      ] },
    ]);
    t.sendKey(jumpNextKey); // succeeds
    t.expectViewRoot(1);
    t.sendKeys('jx');
    return t.expect([
      'third',
      { text: 'first', children: [
        'econd'
      ] },
    ]);
  });

  it('erases history properly', function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second'
      ] },
      { text: 'third', children: [
        'fourth'
      ] },
    ]);
    t.expectViewRoot(0);
    t.expectJumpIndex(0, 1);
    t.sendKeys(']');
    t.expectViewRoot(1);
    t.expectJumpIndex(1, 2);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.expectJumpIndex(0, 2);

    t.sendKeys('jj]');
    t.expectViewRoot(3);
    t.expectJumpIndex(1, 2);

    t.sendKeys('[kk]');
    t.expectViewRoot(1);
    t.expectJumpIndex(3, 4);

    t.sendKeys('[');
    t.expectViewRoot(0);
    t.expectJumpIndex(4, 5);

    t.sendKeys('dd');
    t.expect([
      { text: 'third', children: [
        'fourth'
      ] },
    ]);

    t.sendKey(jumpPreviousKey);
    // skips both which is gone, and thing which is same
    t.expectViewRoot(3);
    t.expectJumpIndex(1, 5);

    t.sendKey(jumpNextKey);
    t.expectViewRoot(0);
    t.expectJumpIndex(2, 5);

    // can't go forward for same reason
    // possibly bad behavior since we've now cut off access to future jump history?
    t.sendKey(jumpNextKey);
    t.expectViewRoot(0);
    return t.expectJumpIndex(2, 5);
  });

  it('tries to return cursor position', function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second',
        'cursor'
      ] },
      'third'
    ]);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);

    t.sendKeys(']');
    t.expectViewRoot(1);
    t.expectCursor(1, 0);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.sendKey(jumpNextKey);
    t.sendKeys('j');
    t.expectCursor(2, 0);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.sendKey(jumpNextKey);
    t.expectViewRoot(1);
    t.expectCursor(2, 0);

    // still goes to cursor despite reordering
    t.sendKeys('jddP');
    t.expect([
      { text: 'first', children: [
        'cursor',
        'second'
      ] },
      'third'
    ]);
    t.expectViewRoot(1);
    t.expectCursor(3, 0);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.sendKey(jumpNextKey);
    t.expectViewRoot(1);
    t.expectCursor(3, 0);

    t.expectJumpIndex(1);
    t.sendKeys('[]'); // go back out and in
    t.expectJumpIndex(3);

    // doesn't go to cursor anymore
    t.sendKeys('dd');
    t.expect([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    t.expectViewRoot(1);
    t.expectCursor(2, 0);

    t.sendKey(jumpPreviousKey);
    t.sendKeys('G');
    t.expect([
      { text: 'first', children: [
        'second'
      ] },
      'third'
    ]);
    t.expectViewRoot(0);
    t.expectCursor(4, 0);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(1);
    t.expectCursor(2, 0); // cursor changed since 3 is no longer within view root

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.expectCursor(1, 0); // last cursor hasn't changed

    // verify stuff
    t.sendKey(jumpNextKey);
    t.expectViewRoot(1);
    t.expectCursor(2, 0);

    t.sendKey(jumpNextKey);
    t.expectViewRoot(0);
    t.expectCursor(4, 0);

    // delete last child of 1
    t.sendKeys('kdd');
    t.expect([
      'first',
      'third'
    ]);

    // succeeds despite no children
    t.sendKey(jumpNextKey);
    t.expectViewRoot(1);
    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);

    t.sendKeys('ook');
    t.sendKey('tab');
    t.sendKey('esc');
    t.expect([
      { text: 'first', children: [
        'ok'
      ] },
      'third'
    ]);

    t.sendKey(jumpNextKey);
    t.expectViewRoot(1);
    t.expectCursor(1, 1);

    t.expectJumpIndex(3);
    t.sendKeys('u');
    t.expectJumpIndex(4);
    t.expect([
      'first',
      'third'
    ]);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);

    t.expectJumpIndex(4);
    t.sendKey(jumpPreviousKey);
    return t.expectJumpIndex(3);
  });

  it('considers clones the same', function() {
    let t = new TestCase([
      { text: 'first', children: [
        'second',
        'cursor'
      ] },
      'third'
    ]);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);

    t.sendKeys(']');
    t.expectViewRoot(1);
    t.expectCursor(1, 0);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.expectJumpIndex(0);
    t.sendKey(jumpNextKey);
    t.expectCursor(1, 0);
    t.expectJumpIndex(1);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.expectJumpIndex(0);
    t.sendKeys('dd');
    t.expectCursor(4, 0);
    t.expect([ 'third' ]);

    // unable to jump because of delete
    t.sendKey(jumpNextKey);
    t.expectCursor(4, 0);
    t.expectJumpIndex(0);

    t.sendKeys('p');
    t.expect([
      'third',
      { text: 'first', children: [
        'second',
        'cursor'
      ] }
    ]);
    // now able to jump to clone
    t.sendKey(jumpNextKey);
    t.expectCursor(1, 0);
    t.expectJumpIndex(1);

    t.sendKey(jumpPreviousKey);
    t.expectCursor(1, 0);
    return t.expectJumpIndex(0);
  });

  return it('skips deleted rows', function() {
    let t = new TestCase([
      'cursor',
      { text: 'first', children: [
        { text: 'second', children: [
          'third'
        ] }
      ] },
    ]);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);
    t.expectJumpIndex(0);

    t.sendKeys('jjj');
    t.sendKey('enter');
    t.expectViewRoot(4);
    t.expectCursor(4, 0);
    t.expectJumpIndex(1);

    t.sendKey('[');
    t.expectJumpIndex(2);
    t.expectViewRoot(3);
    t.expectCursor(4, 0);
    t.sendKeys('kdd');
    t.expectJumpIndex(3);
    t.expectViewRoot(2);
    t.expectCursor(2, 0);

    t.sendKey(jumpPreviousKey);
    t.expectViewRoot(0);
    t.expectCursor(1, 0);
    return t.expectJumpIndex(0);
  });
});
