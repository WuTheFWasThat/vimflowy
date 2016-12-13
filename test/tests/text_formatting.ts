/* globals describe, it */
import TestCase from '../testcase';

let boldKey = 'ctrl+B';
let italicizeKey = 'ctrl+I';
let underlineKey = 'ctrl+U';
let strikethroughKey = 'ctrl+enter';
let siblingDownKey = '}';
let siblingUpKey = '{';

describe('text formatting', function() {
  it('works in insert mode', async function() {
    let t = new TestCase(['']);
    t.sendKeys('i');
    t.sendKey(underlineKey);
    t.sendKeys('underline');
    t.sendKey(underlineKey);
    t.sendKeys(' ');
    t.sendKey(strikethroughKey);
    t.sendKeys('strikethrough');
    t.sendKey(strikethroughKey);
    t.sendKey('esc');
    t.expect([
      {
        text:            'underline strikethrough',
        properties: {
          underline:     '.........              ',
          strikethrough: '          .............',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:            'underline ',
        properties: {
          underline:     '......... ',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:            'underline',
        properties: {
          underline:     '.........',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect(['']);
    // redo knows the format
    t.sendKey('ctrl+r');
    t.expect([
      {
        text:            'underline',
        properties: {
          underline:     '.........',
        },
      },
    ]);
    t.sendKey('ctrl+r');
    t.expect([
      {
        text:            'underline ',
        properties: {
          underline:     '......... ',
        },
      },
    ]);
    t.sendKey('ctrl+r');
    t.expect([
      {
        text:            'underline strikethrough',
        properties: {
          underline:     '.........              ',
          strikethrough: '          .............',
        },
      },
    ]);
    await t.done();
  });

  it('correctly detects cursor style in insert mode', async function() {
    let t = new TestCase(['']);
    t.sendKeys('i');
    t.sendKeys('normal, ');
    t.sendKey(italicizeKey);
    t.sendKeys('italic, ');
    t.sendKey(boldKey);
    t.sendKeys('bold italic, ');
    t.sendKey(italicizeKey);
    t.sendKeys('bold');
    t.expect([
      {
        text:     'normal, italic, bold italic, bold',
        properties: {
          bold:   '                .................',
          italic: '        .....................    ',
        },
      },
    ]);
    t.sendKey('esc');
    // beginning of line, gets cursor correctly
    t.sendKeys('0iab');
    t.sendKey('esc');
    t.expect([
      {
        text:     'abnormal, italic, bold italic, bold',
        properties: {
          bold:   '                  .................',
          italic: '          .....................    ',
        },
      },
    ]);
    t.sendKeys('0cWv');
    t.sendKey('esc');
    t.expect([
      {
        text:     'vitalic, bold italic, bold',
        properties: {
          bold:   '         .................',
          italic: '......................    ',
        },
      },
    ]);
    // uses style left of cursor
    t.sendKeys('Wia');
    t.sendKey('right');
    t.sendKeys('r');
    t.sendKey('esc');
    t.expect([
      {
        text:     'vitalic, abrold italic, bold',
        properties: {
          bold:   '          ..................',
          italic: '........................    ',
        },
      },
    ]);

    t.sendKeys('yy');
    // replace preserves style
    t.sendKeys('flrafora');
    t.sendKey('esc');
    t.expect([
      {
        text:     'vitalic, abroad italic, bald',
        properties: {
          bold:   '          ..................',
          italic: '........................    ',
        },
      },
    ]);

    // pastes properly
    t.sendKeys('p');
    t.expect([
      {
        text:     'vitalic, abroad italic, bald',
        properties: {
          bold:   '          ..................',
          italic: '........................    ',
        },
      },
      {
        text:     'vitalic, abrold italic, bold',
        properties: {
          bold:   '          ..................',
          italic: '........................    ',
        },
      },
    ]);
    await t.done();
  });

  it('preserves cursor style on next line in insert mode', async function() {
    let t = new TestCase(['']);
    t.sendKeys('i');
    t.sendKey(boldKey);
    t.sendKeys('this');
    t.sendKey('enter');
    t.sendKeys('is');
    t.sendKey('enter');
    t.sendKey(italicizeKey);
    t.sendKeys('bold');
    t.expect([
      {
        text:     'this',
        properties: {
          bold:   '....',
        },
      },
      {
        text:     'is',
        properties: {
          bold:   '..',
        },
      },
      {
        text:     'bold',
        properties: {
          bold:   '....',
          italic: '....',
        },
      },
    ]);
    t.sendKey('esc');
    t.sendKeys('onormal');
    t.expect([
      {
        text:     'this',
        properties: {
          bold:   '....',
        },
      },
      {
        text:     'is',
        properties: {
          bold:   '..',
        },
      },
      {
        text:     'bold',
        properties: {
          bold:   '....',
          italic: '....',
        },
      },
      'normal',
    ]);
    t.sendKey('esc');
    await t.done();
  });

  it('works with delete/paste', async function() {
    let t = new TestCase([
      {
        text:     'bim',
        properties: {
          bold:   '. .',
          italic: ' ..',
        },
      },
    ]);
    t.sendKeys('xp');
    t.expect([
      {
        text:     'ibm',
        properties: {
          bold:   ' ..',
          italic: '. .',
        },
      },
    ]);
    await t.done();
  });

  it('works in normal mode', async function() {
    let t = new TestCase([
      'test',
    ]);
    t.sendKey(strikethroughKey);
    t.expect([
      {
        text:            'test',
        properties: {
          strikethrough: '....',
        },
      },
    ]);
    t.sendKey(strikethroughKey);
    t.expect([
      'test',
    ]);
    await t.done();

    t = new TestCase([
      {
        text:     'test',
        properties: {
          bold:   '... ',
        },
      },
    ]);
    t.sendKeys('ll');
    t.sendKey(boldKey);
    t.expect([
      {
        text:     'test',
        properties: {
          bold:   '....',
        },
      },
    ]);
    t.sendKey(boldKey);
    t.expect([
      'test',
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:     'test',
        properties: {
          bold:   '....',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:     'test',
        properties: {
          bold:   '... ',
        },
      },
    ]);
    // cursor ends up where it was
    t.sendKeys('x');
    t.expect([
      {
        text:     'tet',
        properties: {
          bold:   '.. ',
        },
      },
    ]);
    await t.done();
  });

  it('preserves cursor in normal mode', async function() {
    let t = new TestCase([
      'test',
    ]);
    t.sendKey('l');
    t.expectCursor(1, 1);
    t.sendKey(strikethroughKey);
    t.expectCursor(1, 1);
    t.expect([
      {
        text:            'test',
        properties: {
          strikethrough: '....',
        },
      },
    ]);
    await t.done();
  });

  it('works in visual mode', async function() {
    let t = new TestCase([ 'hello world' ]);
    t.sendKeys('ve');
    t.sendKey(boldKey);
    t.expect([
      {
        text:   'hello world',
        properties: {
          bold: '.....      ',
        },
      },
    ]);
    t.sendKey('x');
    t.expect([
      {
        text:   'hell world',
        properties: {
          bold: '....      ',
        },
      },
    ]);
    t.sendKeys('v$');
    t.sendKey(strikethroughKey);
    t.expect([
      {
        text:            'hell world',
        properties: {
          bold:          '....      ',
          strikethrough: '    ......',
        },
      },
    ]);
    t.sendKeys('x');
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          '....     ',
          strikethrough: '    .....',
        },
      },
    ]);
    t.sendKeys('vb');
    t.sendKey(strikethroughKey);
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          '....     ',
          strikethrough: '    .    ',
        },
      },
    ]);
    t.sendKeys('hvb');
    t.sendKey(boldKey);
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          '.....    ',
          strikethrough: '    .    ',
        },
      },
    ]);
    t.sendKeys('v');
    t.sendKey(boldKey);
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          ' ....    ',
          strikethrough: '    .    ',
        },
      },
    ]);
    t.sendKeys('v$');
    t.sendKey(strikethroughKey);
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          ' ....    ',
          strikethrough: '.........',
        },
      },
    ]);
    t.sendKeys('v0');
    t.sendKey(strikethroughKey);
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          ' ....    ',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          ' ....    ',
          strikethrough: '.........',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:            'hell worl',
        properties: {
          bold:          ' ....    ',
          strikethrough: '    .    ',
        },
      },
    ]);
    await t.done();
  });

  it('works in visual line mode', async function() {
    let t = new TestCase([ 'blah', 'blah', 'blah']);
    t.sendKeys('Vjj');
    t.sendKey(boldKey);
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
      },
    ]);
    t.sendKeys('ggVjj');
    t.sendKey(boldKey);
    t.expect([ 'blah', 'blah', 'blah' ]);
    await t.done();

    t = new TestCase([
      {
        text:   'blah',
        properties: {
          bold: '... ',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text:   'blah',
        properties: {
          bold: '    ',
        },
        children: ['fo', 'fum'],
      },
      {
        text:   'blah',
        properties: {
          bold: '   .',
        },
      },
    ]);
    t.sendKeys(['V', siblingDownKey, siblingDownKey, boldKey]);
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: ['fo', 'fum'],
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
      },
    ]);
    t.sendKeys(['G', 'V', siblingUpKey, boldKey]);
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text: 'blah',
        children: ['fo', 'fum'],
      },
      'blah',
    ]);
    t.sendKeys(['V', siblingUpKey, boldKey]);
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: ['fo', 'fum'],
      },
      'blah',
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text: 'blah',
        children: ['fo', 'fum'],
      },
      'blah',
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
        children: ['fo', 'fum'],
      },
      {
        text:   'blah',
        properties: {
          bold: '....',
        },
      },
    ]);
    t.sendKeys('u');
    t.expect([
      {
        text:   'blah',
        properties: {
          bold: '... ',
        },
        children: [{text: 'fee', properties: {bold: '. .'}}, 'fi'],
      },
      {
        text: 'blah',
        children: ['fo', 'fum'],
      },
      {
        text:   'blah',
        properties: {
          bold: '   .',
        },
      },
    ]);
    await t.done();
  });
});
