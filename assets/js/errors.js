import _ from 'lodash';

// takes a constructor and returns an error class
let errorFactory = function(f) {
  let g = function() {
    this.stack = new Error().stack;
    return f.apply(this, arguments);
  };
  g.prototype = Object.create(Error.prototype);
  return g;
};

export let NotImplemented = errorFactory(function() { return this.message = 'Not implemented!'; });
export let UnexpectedValue = errorFactory(function(name, value) {
  return this.message = `Unexpected value for \`${name}\`: ${value}`;
});
export let GenericError = errorFactory(function(message) { this.message = message; });
export let SchemaVersion = errorFactory(function(message) { this.message = message; });

// is special because ignored by error handling in index.js
export let DataPoisoned = errorFactory(function(message) { this.message = message; });

//#########
// asserts
//#########

let AssertionError = errorFactory(function(message) { return this.message = `Assertion error: ${message}`; });
export { AssertionError };

export function assert(a, message='assert error') {
  if (!a) { throw new AssertionError(`${message}\nExpected ${a} to be true`); }
}

export function assert_equals(a, b, message='assert_equals error') {
  if (a !== b) { throw new AssertionError(`${message}\nExpected ${a} == ${b}`); }
}

export function assert_not_equals(a, b, message='assert_not_equals error') {
  if (a === b) { throw new AssertionError(`${message}\nExpected ${a} != ${b}`); }
}

// for asserting object equality
export function assert_deep_equals(a, b, message='assert_deep_equals error') {
  if (!_.isEqual(a, b)) {
    throw new AssertionError(`${message}
      \nExpected:
      \n${JSON.stringify(a, null, 2)}
      \nBut got:
      \n${JSON.stringify(b, null, 2)}
    `
    );
    throw new Error(message);
  }
}

export function assert_arrays_equal(arr_a, arr_b) {
  let a_minus_b = _.difference(arr_a, arr_b);
  if (a_minus_b.length) { throw new AssertionError(`Arrays not same, first contains: ${a_minus_b}`); }
  let b_minus_a = _.difference(arr_b, arr_a);
  if (b_minus_a.length) { throw new AssertionError(`Arrays not same, second contains: ${b_minus_a}`); }
}
