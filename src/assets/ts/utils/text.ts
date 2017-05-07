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

// Helpers to build up regex that finds the start of a word
// Ignore the groups, for the sake of matching (TODO: do that in the caller?)
//
// Allow whitespace or beginning of line, then open paren
export const silentWordStartRegex = '(?:\\s|^)(?:\\()*';
// Allow end parens, punctuation, then whitespace or end of line
export const silentWordEndRegex = '(?:\\))*(?:\\.|,|!|\\?|\\:|\\;)*(?:\\s|$)';

// Returns regex whose first match is a "word" with certain properties (according to a regex string).
// Note the word needn't be a word in the sense of containing no whitespace - that is up to the regex_str to decide.
// It just needs to start on something like a word-start and end on something like a word-end.
export function matchWordRegex(regex_str: string) {
  return new RegExp(silentWordStartRegex + '(' + regex_str + ')' + silentWordEndRegex);
}
