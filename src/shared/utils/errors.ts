import * as _ from 'lodash';

export class ExtendableError extends Error {
  constructor(message: string, name?: string) {
    super(message);
    this.name = name || this.constructor.name;
    this.stack = (new Error(message)).stack;
  }
}

export class NotImplemented extends ExtendableError {
  constructor(m = '') {
    super(m ? `Not implemented: ${m}!` : 'Not implemented!');
  }
}

export class UnexpectedValue extends ExtendableError {
  constructor(name: string, value: any) {
    super(`Unexpected value for \`${name}\`: ${value}`);
  }
}

export class GenericError extends ExtendableError {
  // constructor(m: string) { super(m); }
}

// error class for errors that we can reasonably expect to happen
// e.g. bad user input, multiple users
// is special because ignored by error handling in app.tsx
export class ExpectedError extends ExtendableError {
  // constructor(m: string) { super(m); }
}

///////////
// asserts
///////////

export class AssertionError extends ExtendableError {
  constructor(m: string) {
    super(`Assertion error: ${m}`);
  }
}

export function assert(a: boolean, message = 'assert error') {
  if (!a) {
    throw new AssertionError(`${message}\nExpected ${a} to be true`);
  }
}

export function assert_equals(a: any, b: any, message = 'assert_equals error') {
  if (a !== b) { throw new AssertionError(`${message}\nExpected ${a} == ${b}`); }
}

export function assert_not_equals(a: any, b: any, message = 'assert_not_equals error') {
  if (a === b) { throw new AssertionError(`${message}\nExpected ${a} != ${b}`); }
}

// for asserting object equality
export function assert_deep_equals(a: any, b: any, message = 'assert_deep_equals error') {
  if (!_.isEqual(a, b)) {
    throw new AssertionError(`${message}
      \nExpected:
      \n${JSON.stringify(a, null, 2)}
      \nBut got:
      \n${JSON.stringify(b, null, 2)}
    `);
  }
}

export function assert_arrays_equal(arr_a: Array<any>, arr_b: Array<any>) {
  const a_minus_b = _.difference(arr_a, arr_b);
  if (a_minus_b.length) { throw new AssertionError(`Arrays not same, first contains: ${a_minus_b}`); }
  const b_minus_a = _.difference(arr_b, arr_a);
  if (b_minus_a.length) { throw new AssertionError(`Arrays not same, second contains: ${b_minus_a}`); }
}
