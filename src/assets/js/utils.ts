import $ from 'jquery';
import * as _ from 'lodash';

import { Char } from './types';

export function id<T>(x: T): T { return x; }

// gets slice of an array, *inclusive*
export function getSlice<T>(array: Array<T>, min: number, max: number): Array<T> {
  if (max === -1) {
    if (array.length === 0) {
      return [];
    }
    max = array.length - 1;
  }
  return array.slice(min, max + 1);
}

// NOTE: fn should not have side effects,
// since we parallelize the calls
export async function asyncFilter<T>(
  arr: Array<T>, fn: (el: T) => Promise<boolean>
) {
  const result: Array<{ el: T, i: number }> = [];
  await Promise.all(
    arr.map(async (el, i) => {
      if (await fn(el)) {
        result.push({ el, i });
      }
    })
  );
  return _.sortBy(result, (x) => x.i).map((x) => x.el);
}

// TODO: is quite silly to consider undefined as whitespace...
export function isWhitespace(chr: string | undefined) {
  return (chr === ' ') || (chr === '\n') || (chr === undefined);
}

// a Char with no text formatting
export function plainChar(chr: string): Char {
  return { char: chr, properties: {} };
}

// NOTE: currently unused
export function isPunctuation(chr: string) {
  return chr === '.' || chr === ',' || chr === '!' || chr === '?';
}

const urlRegex = /^https?:\/\/([^\s]+\.[^\s]+$|localhost)/;
export function isLink(word: string) {
  return urlRegex.test(word);
}

export function mimetypeLookup(filename: string): string | undefined {
  const parts = filename.split('.');
  const extension = parts.length > 1 ? parts[parts.length - 1] : '';
  const extensionLookup: {[key: string]: string} = {
    'json': 'application/json',
    'txt': 'text/plain',
    '': 'text/plain',
  };
  return extensionLookup[extension.toLowerCase()];
}

// TODO: get jquery typing to work?
export function scrollDiv($elem: any, amount: number) {
  // # animate.  seems to not actually be great though
  // $elem.stop().animate({
  //     scrollTop: $elem[0].scrollTop + amount
  // }, 50)
  return $elem.scrollTop($elem.scrollTop() + amount);
}

export function isScrolledIntoView(elem: Element, container: Element) {
  const $elem = $(elem);
  const $container = $(container);

  const docViewTop = $container.offset().top;
  const docViewBottom = docViewTop + $container.outerHeight();

  const elemTop = $elem.offset().top;
  const elemBottom = elemTop + $elem.height();

  return ((elemBottom <= docViewBottom) && (elemTop >= docViewTop));
}

export function getParameterByName(name: string) {
  name = name.replace(/[\[\]]/g, '\\$&');
  const regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)');
  const results = regex.exec(window.location.href);
  if (!results) { return null; }
  if (!results[2]) { return ''; }
  return decodeURIComponent(results[2].replace(/\+/g, ' '));
}
