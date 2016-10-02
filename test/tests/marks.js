/* globals describe, it */
import TestCase from '../testcase';
import * as Marks from '../../src/plugins/marks';
import '../../src/assets/js/plugins';

// Testing
TestCase.prototype.expectMarks = function(expected) {
  return this._chain(async () => {
    const marksApi = this.pluginManager.getInfo(Marks.pluginName).value;
    this._expectDeepEqual(await marksApi.listMarks(), expected, 'Wrong marks');
  });
};

describe('marks', function() {
  it('works in basic cases', async function() {
    let t = new TestCase([
      'a line',
      'another line'
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({});
    t.sendKeys('mmarktest');
    t.sendKey('enter');
    t.expectMarks({'marktest': 1});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      'another line'
    ]);

    t.sendKeys('jmtest2');
    t.sendKey('enter');
    t.expectMarks({'marktest': 1, 'test2': 2});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      { text: 'another line', plugins: {mark: 'test2'} }
    ]);

    // unmark
    t.sendKeys('km');
    t.sendKey('enter');
    t.expectMarks({'test2': 2});
    t.expect([
      'a line',
      { text: 'another line', plugins: {mark: 'test2'} }
    ]);

    t.sendKeys('jm');
    t.sendKey('enter');
    t.expectMarks({});
    t.expect([
      'a line',
      'another line'
    ]);

    t.sendKeys('dd');
    t.expect([
      'a line'
    ]);

    // undo works
    t.sendKeys('uu');
    t.expectMarks({'test2': 2});
    t.expect([
      'a line',
      { text: 'another line', plugins: {mark: 'test2'} }
    ]);

    t.sendKeys('u');
    t.expectMarks({'marktest': 1, 'test2': 2});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      { text: 'another line', plugins: {mark: 'test2'} }
    ]);

    t.sendKeys('u');
    t.expectMarks({'marktest': 1});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      'another line'
    ]);

    // redo works
    t.sendKey('ctrl+r');
    t.expectMarks({'marktest': 1, 'test2': 2});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      { text: 'another line', plugins: {mark: 'test2'} }
    ]);

    // backspace and left and right work
    t.sendKeys('mhallo');
    t.sendKey('left');
    t.sendKey('backspace');
    t.sendKey('enter');
    t.expectMarks({'marktest': 1, 'halo': 2});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      { text: 'another line', plugins: {mark: 'halo'} }
    ]);

    // cancel works
    t.sendKeys('mbye');
    t.sendKey('esc');
    t.expectMarks({'marktest': 1, 'halo': 2});
    t.expect([
      { text: 'a line', plugins: {mark: 'marktest'} },
      { text: 'another line', plugins: {mark: 'halo'} }
    ]);
    await t.done();
  });

  it('works with paste', async function() {
    let t = new TestCase([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      { text: 'line 2', plugins: {mark: 'mark2'} }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({'mark1': 1, 'mark2': 2});
    t.sendKeys('dd');
    t.expect([
      { text: 'line 2', plugins: {mark: 'mark2'} }
    ]);
    t.expectMarks({'mark2': 2});
    t.sendKeys('p');
    t.expect([
      { text: 'line 2', plugins: {mark: 'mark2'} },
      { text: 'line 1', plugins: {mark: 'mark1'} }
    ]);
    t.expectMarks({'mark2': 2, 'mark1': 1});
    await t.done();
  });

  it('doesnt mark when the mark exists, from delete', async function() {
    let t = new TestCase([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      { text: 'line 2', plugins: {mark: 'mark2'} },
    ], {plugins: [Marks.pluginName]});
    t.sendKeys('mmark2');
    t.sendKey('enter');
    // does nothing due to mark2 being taken
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      { text: 'line 2', plugins: {mark: 'mark2'} },
    ]);
    t.expectMarks({'mark1': 1, 'mark2': 2});

    // once line is deleted, we can mark though
    t.sendKeys('jdd');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark1'} },
    ]);
    t.expectMarks({'mark1': 1});

    t.sendKeys('mmark2');
    t.sendKey('enter');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark2'} },
    ]);
    t.expectMarks({'mark2': 1});

    // paste can't reapply the mark
    t.sendKeys('p');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark2'} },
      'line 2'
    ]);
    t.expectMarks({'mark2': 1});

    t.sendKeys('kmmark3');
    t.sendKey('enter');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark3'} },
      'line 2'
    ]);
    t.expectMarks({'mark3': 1});
    await t.done();
  });

  it('doesnt mark when the mark exists, from yank', async function() {
    let t = new TestCase([
      { text: 'line 1', plugins: {mark: 'mark1'} },
    ], {plugins: [Marks.pluginName]});

    t.sendKeys('yy');
    t.sendKeys(['d', 'm']);
    t.expect([
      'line 1'
    ]);
    t.expectMarks({});

    t.sendKeys('u');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark1'} },
    ]);
    t.expectMarks({'mark1': 1});

    // paste can't reapply the mark
    t.sendKeys('p');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      'line 1'
    ]);
    t.expectMarks({'mark1': 1});

    t.sendKeys('kmmark2');
    t.sendKey('enter');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark2'} },
      'line 1'
    ]);
    t.expectMarks({'mark2': 1});

    // paste can now reapply the mark
    t.sendKeys('p');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark2'} },
      { text: 'line 1', plugins: {mark: 'mark1'} },
      'line 1'
    ]);
    t.expectMarks({'mark2': 1, 'mark1': 3});
    await t.done();
  });

  it('can be visited with gm', async function() {
    let t = new TestCase([
      { text: '@mark2 @mark3', children: [
        'line',
        { text: 'line', plugins: {mark: 'mark3'} },
      ] },
      { text: 'stuff', plugins: {mark: 'mark2'}, children: [
        'more stuff'
      ] }
    ], {plugins: [Marks.pluginName]});
    t.sendKeys('gmx');
    t.expectViewRoot(4);
    t.expect([
      { text: '@mark2 @mark3', children: [
        'line',
        { text: 'line', plugins: {mark: 'mark3'} }
      ] },
      { text: 'tuff', plugins: {mark: 'mark2'}, children: [
        'more stuff'
      ] }
    ]);
    // goes nowhere
    t.sendKeys('$gmx');
    t.expect([
      { text: '@mark2 @mark3', children: [
        'line',
        { text: 'line', plugins: {mark: 'mark3'} }
      ] },
      { text: 'tuf', plugins: {mark: 'mark2'}, children: [
        'more stuff'
      ] }
    ]);
    // back to top
    t.sendKey('shift+enter');
    t.sendKeys('gg');
    t.expectViewRoot(0);
    t.expectCursor(1, 0);
    t.sendKeys('$gmx');
    t.expectViewRoot(3);
    t.expectCursor(3, 2);
    t.expect([
      { text: '@mark2 @mark3', children: [
        'line',
        { text: 'lin', plugins: {mark: 'mark3'} }
      ] },
      { text: 'tuf', plugins: {mark: 'mark2'}, children: [
        'more stuff'
      ] }
    ]);
    await t.done();
  });

  it('can be searched for', async function() {
    let t = new TestCase([
      { text: 'whoo', plugins: {mark: 'hip'} },
      { text: 'yay', plugins: {mark: 'hooray'}, children: [
        'hip',
        'hip',
        { text: 'hooray', plugins: {mark: 'yay'} }
      ] },
      { text: 'awesome', plugins: {mark: 'whoo'} }
    ], {plugins: [Marks.pluginName]});
    t.sendKeys('`w');
    t.sendKey('enter');
    t.sendKeys('x');
    t.expect([
      { text: 'whoo', plugins: {mark: 'hip'} },
      { text: 'yay', plugins: {mark: 'hooray'}, children: [
        'hip',
        'hip',
        { text: 'hooray', plugins: {mark: 'yay'} }
      ] },
      { text: 'wesome', plugins: {mark: 'whoo'} }
    ]);

    t.sendKeys('`r');
    t.sendKey('enter');
    t.sendKeys('x');
    // goes nowhere
    t.expect([
      { text: 'whoo', plugins: {mark: 'hip'} },
      { text: 'yay', plugins: {mark: 'hooray'}, children: [
        'hip',
        'hip',
        { text: 'hooray', plugins: {mark: 'yay'} }
      ] },
      { text: 'esome', plugins: {mark: 'whoo'} }
    ]);

    t.sendKeys('`ho');
    t.sendKey('enter');
    t.sendKeys('x');
    t.expect([
      { text: 'whoo', plugins: {mark: 'hip'} },
      { text: 'ay', plugins: {mark: 'hooray'}, children: [
        'hip',
        'hip',
        { text: 'hooray', plugins: {mark: 'yay'} }
      ] },
      { text: 'esome', plugins: {mark: 'whoo'} }
    ]);
    t.sendKeys('`hi');
    t.sendKey('enter');
    t.sendKeys('x');
    t.expect([
      { text: 'hoo', plugins: {mark: 'hip'} },
      { text: 'ay', plugins: {mark: 'hooray'}, children: [
        'hip',
        'hip',
        { text: 'hooray', plugins: {mark: 'yay'} }
      ] },
      { text: 'esome', plugins: {mark: 'whoo'} }
    ]);
    await t.done();
  });

  it('works with deletion', async function() {
    let t = new TestCase([
      { text: 'row', plugins: {mark: 'row'}, children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            { text: 'grandgrandchild', plugins: {mark: 'too'} },
            { text: 'grandgrandchild', plugins: {mark: 'deep'} },
          ] }
        ] }
      ] },
      'random',
      'random'
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({'row': 1, 'too': 4, 'deep': 5});

    t.sendKeys('`t');
    t.expectNumMenuResults(1);
    t.sendKey('esc');

    t.sendKeys('dd');
    t.expect([ 'random', 'random' ]);
    t.expectMarks({});

    t.sendKeys('`t');
    t.expectNumMenuResults(0);
    t.sendKey('esc');

    t.sendKeys('mrow');
    t.sendKey('enter');
    t.expectMarks({'row': 6});

    t.sendKeys('jmtoo');
    t.sendKey('enter');
    t.expectMarks({'row': 6, 'too': 7});

    // and marks can fail to apply
    t.sendKeys('p');
    t.expect([
      { text: 'random', plugins: {mark: 'row'} },
      { text: 'random', plugins: {mark: 'too'} },
      { text: 'row', children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            'grandgrandchild',
            { text: 'grandgrandchild', plugins: {mark: 'deep'} },
          ] }
        ] }
      ] }
    ]);
    t.expectMarks({'row': 6, 'too': 7, 'deep': 5});
    await t.done();
  });

  it('works with deletion and paste of nested stuff', async function() {
    let t = new TestCase([
      { text: 'row', plugins: {mark: 'row'}, children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            { text: 'grandgrandchild', plugins: {mark: 'too'} },
            { text: 'grandgrandchild', plugins: {mark: 'deep'} },
          ] }
        ] }
      ] },
      'random'
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({'row': 1, 'too': 4, 'deep': 5});

    t.sendKeys('dd');
    t.expect([ 'random' ]);
    t.expectMarks({});

    t.sendKeys('p');
    t.expect([
      'random',
      { text: 'row', plugins: {mark: 'row'}, children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            { text: 'grandgrandchild', plugins: {mark: 'too'} },
            { text: 'grandgrandchild', plugins: {mark: 'deep'} },
          ] }
        ] }
      ] }
    ]);
    t.expectMarks({'row': 1, 'too': 4, 'deep': 5});

    t.sendKeys('yru');
    t.expect([ 'random' ]);
    t.expectMarks({});

    t.sendKeys('mtoo');
    t.sendKey('enter');
    t.expectMarks({'too': 6});

    // and marks can fail to apply
    t.sendKeys('p');
    t.expect([
      { text: 'random', plugins: {mark: 'too'} },
      { text: 'row', plugins: {mark: 'row'}, children: [
        { text: 'child', children: [
          { text: 'grandchild', children: [
            'grandgrandchild',
            { text: 'grandgrandchild', plugins: {mark: 'deep'} }
          ] }
        ] }
      ] }
    ]);
    // new IDs happen since it's the second paste
    t.expectMarks({'row': 7, 'too': 6, 'deep': 11});
    await t.done();
  });

  it('can be cloned and pasted', async function() {
    let t = new TestCase([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      { text: 'line 2', plugins: {mark: 'mark2'}, children: [
        'line 2.1'
      ] }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({'mark1': 1, 'mark2': 2});
    t.sendKeys('yc');
    t.expectMarks({'mark1': 1, 'mark2': 2});
    t.sendKeys('jj');
    t.sendKeys('p');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark1'}, id: 1 },
      { text: 'line 2', plugins: {mark: 'mark2'}, children: [
        'line 2.1',
        { clone: 1 }
      ] }
    ]);
    t.expectMarks({'mark1': 1, 'mark2': 2});

    t.sendKeys('ggdd');
    t.expect([
      { text: 'line 2', plugins: {mark: 'mark2'}, children: [
        'line 2.1',
        { text: 'line 1', plugins: {mark: 'mark1'} }
      ] }
    ]);
    t.expectMarks({'mark1': 1, 'mark2': 2});
    await t.done();
  });

  it('deletes marks only on last clone delete', async function() {
    let t = new TestCase([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      { text: 'line 2', plugins: {mark: 'mark2'}, children: [
        'line 2.1'
      ] }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({'mark1': 1, 'mark2': 2});
    t.sendKeys('yc');
    t.expectMarks({'mark1': 1, 'mark2': 2});
    t.sendKeys('jj');
    t.sendKeys('p');
    t.sendKeys('dd');
    t.expect([
      { text: 'line 1', plugins: {mark: 'mark1'} },
      { text: 'line 2', plugins: {mark: 'mark2'}, children: [
        'line 2.1',
      ] }
    ]);
    t.expectMarks({'mark1': 1, 'mark2': 2});
    t.sendKeys('kk');
    t.sendKeys('dd');
    t.expect([
      { text: 'line 2', plugins: {mark: 'mark2'}, children: [
        'line 2.1',
      ] }
    ]);
    t.expectMarks({'mark2': 2});
    await t.done();
  });

  it('survives transferring to different clone', async function() {
    let t = new TestCase([
      { text: 'Marked clone', plugins: {mark: 'mark'}, children: [
        'Clone child'
      ] },
      { text: 'Not a clone', children: [
        'Not a clone'
      ] }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({ 'mark': 1 });

    t.sendKeys('ycjjp');
    t.expect([
      { text: 'Marked clone', plugins: {mark: 'mark'}, id: 1, children: [
        'Clone child'
      ] },
      { text: 'Not a clone', children: [
        { clone: 1 },
        'Not a clone'
      ] }
    ]);

    t.sendKeys('ggdd');
    t.expect([
      { text: 'Not a clone', children: [
        { text: 'Marked clone', plugins: {mark: 'mark'}, children: [
          'Clone child'
        ] },
        'Not a clone'
      ] }
    ]);
    t.expectMarks({ 'mark': 1 });

    t.sendKeys('dd');
    t.expect([ '' ]);
    t.expectMarks({ });
    await t.done();
  });

  it('works with deletes and clones properly', async function() {
    let t = new TestCase([
      { text: 'parent', children: [
        { text: 'Will be cloned', children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('jycGp');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2, children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('jj');
    t.sendKeys(['m', 'enter']);
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2, children: [
          'Marked child'
        ] },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({});

    t.sendKeys('ggdd');
    t.expect([
      ''
    ]);
    t.expectMarks({});

    t.sendKeys('u');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2, children: [
          'Marked child'
        ] },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({});

    t.sendKeys('u');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2, children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('ggdd');
    t.expect([
      ''
    ]);
    t.expectMarks({});
    await t.done();
  });

  it('remove the last marked instance when it is a descendant of a cloned node', async function() {
    let t = new TestCase([
      { text: 'parent', children: [
        { text: 'Will be cloned', children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('jycGp');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2, children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('jjdd');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2 },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({});
    await t.done();
  });

  it('works with jumps', async function() {
    let t = new TestCase([
      { text: 'okay', plugins: {mark: 'goto'}, children: [
        'stuff'
      ] },
      'third'
    ], {plugins: [Marks.pluginName]});
    t.sendKeys('\'goto');
    t.sendKey('enter');
    t.expectViewRoot(1);
    t.expectCursor(1, 0);
    t.expectJumpIndex(1, 2);

    // does nothing due to being the same spot
    t.sendKeys('\'goto');
    t.sendKey('enter');
    t.expectViewRoot(1);
    t.expectCursor(1, 0);
    t.expectJumpIndex(1, 2);
    await t.done();
  });

  it('node deletion doesnt always mean mark deletion', async function() {
    let t = new TestCase([
      { text: 'parent', children: [
        { text: 'Will be cloned', children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ], {plugins: [Marks.pluginName]});
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('jycGp');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', id: 2, children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] },
        { text: 'blah', children: [
          'blah',
          { clone: 2 }
        ] }
      ] }
    ]);
    t.expectMarks({ 'mark': 3 });

    t.sendKeys('kkdd');
    t.expect([
      { text: 'parent', children: [
        { text: 'Will be cloned', children: [
          { text: 'Marked child', plugins: {mark: 'mark'} }
        ] }
      ] }
    ]);
    t.expectMarks({ 'mark': 3 });
    await t.done();
  });

  it('works with tricky failed re-attach undo case', async function() {
    let t = new TestCase([
      { text: 'row', plugins: {mark: 'mark'}, children: [
        'blah'
      ] },
      'random'
    ], {plugins: [Marks.pluginName]});
    t.sendKeys('dd');
    t.expect([
      'random'
    ]);
    t.sendKeys('mmark');
    t.sendKey('enter');
    t.expect([
      { text: 'random', plugins: {mark: 'mark'} }
    ]);
    t.sendKeys('p');
    t.expect([
      { text: 'random', plugins: {mark: 'mark'} },
      { text: 'row', children: [
        'blah'
      ] }
    ]);
    t.sendKeys('uuu');
    t.expect([
      { text: 'row', plugins: {mark: 'mark'}, children: [
        'blah'
      ] },
      'random'
    ]);
    await t.done();
  });

  it('canonical instance handles non-trivial case, i.e. first parent detached', async function() {
    let t = new TestCase([
      { text: 'parent1', children: [
        { text: 'row', plugins: {mark: 'mark'} }
      ] },
      { text: 'parent2', children: [
        'blah'
      ] }
    ], {plugins: [Marks.pluginName]});
    t.sendKeys('jycjp');
    t.expect([
      { text: 'parent1', children: [
        { text: 'row', plugins: {mark: 'mark'}, id: 2 }
      ] },
      { text: 'parent2', children: [
        { clone: 2 },
        'blah'
      ] }
    ]);
    t.sendKeys('ggdd');
    t.expect([
      { text: 'parent2', children: [
        { text: 'row', plugins: {mark: 'mark'} },
        'blah'
      ] }
    ]);
    t.expectMarks({ 'mark': 2 });
    t.expectCursor(3, 0);
    t.sendKeys('`');
    t.sendKey('enter');
    t.expectCursor(2, 0);
    await t.done();
  });

  // NOTE: THIS SHOULD BE THE LAST TEST!
  it('can be disabled', async function() {
    let t = new TestCase([
      { text: '@mark2 @mark3', children: [
        'line',
        { text: 'line', plugins: {mark: 'mark3'} }
      ] },
      { text: 'stuff', plugins: {mark: 'mark2'}, children: [
        'more stuff'
      ] }
    ], {plugins: [Marks.pluginName]});

    t.disablePlugin(Marks.pluginName);
    t.expect([
      { text: '@mark2 @mark3', children: [
        'line',
        'line'
      ] },
      { text: 'stuff', children: [
        'more stuff'
      ] }
    ]);

    t.sendKeys('gmx');
    t.expect([
      { text: 'mark2 @mark3', children: [
        'line',
        'line'
      ] },
      { text: 'stuff', children: [
        'more stuff'
      ] }
    ]);
    // goes nowhere

    // trying to mark should do nothing
    t.sendKeys('mdd');
    t.sendKey('enter');
    t.expect([
      { text: 'stuff', children: [
        'more stuff'
      ] }
    ]);

    // RE-ENABLE WORKS
    t.enablePlugin(Marks.pluginName);
    t.expect([
      { text: 'stuff', plugins: {mark: 'mark2'}, children: [
        'more stuff'
      ] }
    ]);
    t.sendKeys('mdd');
    t.sendKey('enter');
    t.expect([
      { text: 'stuff', plugins: {mark: 'dd'}, children: [
        'more stuff'
      ] }
    ]);

    t.disablePlugin(Marks.pluginName);
    t.expect([
      { text: 'stuff', children: [
        'more stuff'
      ] }
    ]);
    await t.done();
  });
});
