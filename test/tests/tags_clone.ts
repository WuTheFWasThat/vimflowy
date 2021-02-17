/* globals describe, it */
import TestCase from '../testcase';
import * as Tags from '../../src/plugins/tags';
import * as Marks from '../../src/plugins/marks';
import * as TagsClone from '../../src/plugins/clone_tags';
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

// These test mostly ensure adding clone tags doesnt break tagging, not much testing of clone tags itself
describe('tags_clone', function() {
  it('works in basic cases', async function() {
    let t = new TagsTestCase([
      'a line',
      'another line',
    ], {plugins: [Tags.pluginName, Marks.pluginName, TagsClone.pluginName]});
    t.expectTags({});
    t.sendKeys('#tagtest');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1]});
    t.expect([
      {
      'text': 'tagtest',
        'collapsed': true,
        'plugins': {
          'mark': 'tagtest'
        },
        'children': [
          {
            'text': 'a line',
            'plugins': {
              'tags': [
                'tagtest'
              ]
            },
            'id': 1
          }
        ]
      },
      {
        'clone': 1
      },
      'another line'
    ]
    );

    t.sendKeys('j#test2');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1], 'test2': [2]});

    t.sendKeys('#test3');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1], 'test2': [2], 'test3': [2]});

    // duplicate tags ignored
    t.sendKeys('#test3');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1], 'test2': [2], 'test3': [2]});

    // remove tags
    t.sendKeys('d#1');
    t.expectTags({'tagtest': [1], 'test3': [2]});

    t.sendKeys('kd#');
    t.expectTags({'test3': [2]});

    await t.done();
  });
  it('can be searched for', async function() {
    let t = new TagsTestCase([
      { text: 'hi', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ], {plugins: [Tags.pluginName, Marks.pluginName, TagsClone.pluginName]});
    t.sendKeys('-test3');
    t.sendKey('enter');
    t.sendKeys('x');

    t.sendKeys('-ta');
    t.sendKey('enter');
    t.sendKeys('x');

    t.sendKeys('-test2');
    t.sendKey('enter');
    t.sendKeys('x');
    await t.done();
  });
  it('can repeat', async function() {
    let t = new TagsTestCase([
      { text: 'hi', plugins: {tags: ['tag', 'test3']} },
      { text: 'dog', plugins: {tags: ['test2']} },
    ], {plugins: [Tags.pluginName, Marks.pluginName, TagsClone.pluginName]});
    t.sendKeys('jjjd#1.j');
    t.expectTags({'test2': [4]});
    await t.done();
  });
  it('can undo', async function() {
    let t = new TagsTestCase([
      'a line',
      'another line',
    ], {plugins: [Tags.pluginName, Marks.pluginName, TagsClone.pluginName]});
    t.expectTags({});
    t.sendKeys('#tagtest');
    t.sendKey('enter');
    t.expectTags({'tagtest': [1]});

    t.sendKey('u');
    t.expectTags({});

    t.sendKey('ctrl+r');
    t.expectTags({'tagtest': [1]});

    t.sendKeys('d#');
    t.expectTags({});

    t.sendKey('u');
    t.expectTags({'tagtest': [1]});

    t.sendKey('ctrl+r');
    t.expectTags({});
    await t.done();
  });
});
