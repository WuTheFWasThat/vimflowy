import $ from 'jquery';
import * as _ from 'lodash';

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

export function promiseDebounce(fn: (...args: Array<any>) => Promise<void>) {
  let running = false;
  let pending = false;
  const run = (...args: Array<any>) => {
    running = true;
    fn(...args).then(() => {
      if (pending) {
        pending = false;
        run(...args);
      } else {
        running = false;
      }
    });
  };
  return (...args: Array<any>) => {
    if (!running) {
      run(...args);
    } else {
      pending = true;
    }
  };
};

// TODO: is quite silly to consider undefined as whitespace...
export function isWhitespace(chr: string | undefined) {
  return (chr === ' ') || (chr === '\n') || (chr === undefined);
}

// NOTE: currently unused
export function isPunctuation(chr: string) {
  return chr === '.' || chr === ',' || chr === '!' || chr === '?';
}

const urlRegex = /^https?:\/\/([^\s]+\.[^\s]+$|localhost)/;
export function isLink(text: string): boolean {
  return urlRegex.test(text);
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

export function isScrolledIntoView(elem: any, container: any) {
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
