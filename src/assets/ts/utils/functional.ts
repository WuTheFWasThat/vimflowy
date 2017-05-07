// grab bag of random functions, basically

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

export async function timeout(ns: number) {
  await new Promise((resolve) => setTimeout(resolve, ns));
}
