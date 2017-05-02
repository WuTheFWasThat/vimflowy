/* globals describe, it */
import TestCase from '../testcase';
import * as Todo from '../../src/plugins/todo';
import '../../src/assets/ts/plugins';

const toggleStrikethroughKey = 'ctrl+enter';

describe('todo', function() {
  it('works in basic case', async function() {
    let t = new TestCase([
      'a line',
      'another line',
    ], {plugins: [Todo.pluginName]});
    t.sendKey(toggleStrikethroughKey);
    t.expect([
      '~~a line~~',
      'another line',
    ]);

    t.sendKey(toggleStrikethroughKey);
    t.expect([
      'a line',
      'another line',
    ]);

    t.sendKey('u');
    t.expect([
      '~~a line~~',
      'another line',
    ]);

    t.sendKey('u');
    t.expect([
      'a line',
      'another line',
    ]);
    await t.done();
  });

  it('works in visual line', async function() {
    let t = new TestCase([
      'a line',
      '~~another line~~',
    ], {plugins: [Todo.pluginName]});
    t.sendKeys('Vj');
    t.sendKey(toggleStrikethroughKey);
    t.expect([
      '~~a line~~',
      '~~another line~~',
    ]);

    t.sendKeys('Vk');
    t.sendKey(toggleStrikethroughKey);
    t.expect([
      'a line',
      'another line',
    ]);

    t.sendKeys('Vj');
    t.sendKey(toggleStrikethroughKey);
    t.expect([
      '~~a line~~',
      '~~another line~~',
    ]);

    t.sendKey('u');
    t.expect([
      'a line',
      'another line',
    ]);

    t.sendKey('u');
    t.expect([
      '~~a line~~',
      '~~another line~~',
    ]);

    t.sendKey('u');
    t.expect([
      'a line',
      '~~another line~~',
    ]);
    await t.done();
  });
});
