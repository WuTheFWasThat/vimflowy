import * as _ from 'lodash';

// takes a constructor and returns an error class
const errorFactory = function(f: any, inheritClass = Error) {
  const g: any = function() {
    const e: any = new Error();
    this.stack = e.stack;
    return f.apply(this, arguments);
  };
  g.prototype = Object.create(inheritClass.prototype);
  return g;
};

export const NotImplemented = errorFactory(function() { return this.message = 'Not implemented!'; });
export const UnexpectedValue = errorFactory(function(name: string, value: any) {
  return this.message = `Unexpected value for \`${name}\`: ${value}`;
});
export const GenericError = errorFactory(function(message: string) { this.message = message; });
export const SchemaVersion = errorFactory(function(message: string) { this.message = message; });

// error class for errors that we can reasonably expect to happen
// e.g. bad user input, multiple users
export const ExpectedError = errorFactory(function(message: string) { this.message = message; });
// is special because ignored by error handling in index.js
export const MultipleUsersError = errorFactory(function(message: string) { this.message = message; }, ExpectedError);

///////////
// asserts
///////////

export const AssertionError = errorFactory(function(message: string) {
  this.message = `Assertion error: ${message}`;
});

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
