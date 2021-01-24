/* globals describe, it */
import TestCase from '../testcase';
import * as Tags from '../../src/plugins/tags';
import '../../src/assets/ts/plugins';
import { Row } from '../../src/assets/ts/types';

// Testing
class TagsTestCase extends TestCase {
  public expectTags(expected: {[key: string]: Row[]}) {
    return this._chain(async () => {
      const tagsApi: Tags.TagsPlugin = this.pluginManager.getInfo(Tags.pluginName).value;
      const tags_to_rows: {[key: string]: Row[]} = await tagsApi._getTagsToRows();
      this._expectDeepEqual(tags_to_rows, expected, 'Inconsistent rows_to_tags');
    });
  }
}

describe.only('tags', function() {
  it('works in basic cases', async function() {
    let t = new TagsTestCase([
      'a line',
      'another line',
    ], {plugins: [Tags.pluginName]});
    t.expectTags({});
    t.sendKeys('#tagtest');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      'another line',
    ]);

    t.sendKeys('j#test2');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1], 'test2': [2]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      { text: 'another line', plugins: {tags: ['test2']} },
    ]);

    t.sendKeys('#test3');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1], 'test2': [2], 'test3': [2]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      { text: 'another line', plugins: {tags: ['test2', 'test3']} },
    ]);

    // duplicate tags ignored
    t.sendKeys('#test3');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1], 'test2': [2], 'test3': [2]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      { text: 'another line', plugins: {tags: ['test2', 'test3']} },
    ]);

    // remove tags
    t.sendKeys('d#1');
    t.expectTags({'tagtest': [1], 'test3': [2]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      { text: 'another line', plugins: {tags: ['test3']} },
    ]);

    t.sendKeys('kd#1');
    t.expectTags({'test3': [2]});
    t.expect([
      'a line',
      { text: 'another line', plugins: {tags: ['test3']} },
    ]);

    await t.done();
  });
  it('can be searched for', async function() {
    let t = new TagsTestCase([
      { text: 'hi', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ], {plugins: [Tags.pluginName]});
    t.sendKeys('-test3');
    t.sendKey('enter');
    t.sendKeys('x');
    t.expect([
      { text: 'i', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ]);

    t.sendKeys('-ta');
    t.sendKey('enter');
    t.sendKeys('x');
    t.expect([
      { text: '', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ]);

    t.sendKeys('-test2');
    t.sendKey('enter');
    t.sendKeys('x');
    t.expect([
      { text: '', plugins: {tags: ['tag', 'test3']} },
      { text: 'og', plugins: {tags: ['test2']} },
    ]);
    await t.done();
  });
  it('can repeat', async function() {
    let t = new TagsTestCase([
      { text: 'hi', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ], {plugins: [Tags.pluginName]});
    t.sendKeys('d#1.');
    t.expectTags({'test2': [2]});
    t.expect([
      'hi',
      { text: 'dog', plugins: {tags: ['test2']} },
    ]);
    await t.done();
  });
  it('can undo', async function() {
    let t = new TagsTestCase([
      'a line',
      'another line',
    ], {plugins: [Tags.pluginName]});
    t.expectTags({});
    t.sendKeys('#tagtest');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      'another line',
    ]);

    t.sendKey('u');
    t.expectTags({});
    t.expect([
      'a line',
      'another line',
    ]);

    t.sendKey('ctrl+r');
    t.expectTags({'tagtest': [1]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      'another line',
    ]);

    t.sendKeys('d#1');
    t.expectTags({});
    t.expect([
      'a line',
      'another line',
    ]);

    t.sendKey('u');
    t.expectTags({'tagtest': [1]});
    t.expect([
      { text: 'a line', plugins: {tags: ['tagtest']} },
      'another line',
    ]);

    t.sendKey('ctrl+r');
    t.expectTags({});
    t.expect([
      'a line',
      'another line',
    ]);
    await t.done();
  });
  it('can be disabled', async function() {
    let t = new TagsTestCase([
      { text: 'hi', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ], {plugins: [Tags.pluginName]});

    t.disablePlugin(Tags.pluginName);
    t.expect([
      'hi',
      'dog',
    ]);

    // RE-ENABLE WORKS
    t.enablePlugin(Tags.pluginName);
    t.expect([
      { text: 'hi', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ]);
    await t.done();
  });
});
