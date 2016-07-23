/* globals describe, it */
import TestCase from '../testcase';

let nextSiblingKey = '}';
let prevSiblingKey = '{';

describe('move siblings', () =>
  it('works', async function() {
    let t = new TestCase([
      { text: 'one', children: [
        'uno',
      ] },
      { text: 'two', children: [
        'dos',
      ] },
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]);
    t.sendKeys('x');
    t.sendKey(nextSiblingKey);
    t.sendKeys('x');
    t.expect([
      { text: 'ne', children: [
        'uno',
      ] },
      { text: 'wo', children: [
        'dos',
      ] },
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]);
    t.sendKey(nextSiblingKey);
    t.sendKeys('x');
    t.sendKey(nextSiblingKey);
    t.sendKeys('x');
    t.expect([
      { text: 'ne', children: [
        'uno',
      ] },
      { text: 'wo', children: [
        'dos',
      ] },
      { text: 'cos', children: [
        'tacos',
      ] }
    ]);
    t.sendKey(prevSiblingKey);
    t.sendKeys('x');
    t.expect([
      { text: 'ne', children: [
        'uno',
      ] },
      { text: 'o', children: [
        'dos',
      ] },
      { text: 'cos', children: [
        'tacos',
      ] }
    ]);
    t.sendKey(prevSiblingKey);
    t.sendKeys('x');
    t.expect([
      { text: 'e', children: [
        'uno',
      ] },
      { text: 'o', children: [
        'dos',
      ] },
      { text: 'cos', children: [
        'tacos',
      ] }
    ]);
    t.sendKey(prevSiblingKey);
    t.sendKeys('x');
    t.expect([
      { text: '', children: [
        'uno',
      ] },
      { text: 'o', children: [
        'dos',
      ] },
      { text: 'cos', children: [
        'tacos',
      ] }
    ]);
    await t.done();
  })

);
