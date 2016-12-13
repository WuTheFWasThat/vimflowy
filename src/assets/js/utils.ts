import $ from 'jquery';

import { Char } from './types';

// TODO: is quite silly to consider undefined as whitespace
export function isWhitespace(chr) {
  return (chr === ' ') || (chr === '\n') || (chr === undefined);
}

// a Char with no text formatting
export function plainChar(chr: string): Char {
  return { char: chr, properties: {} };
}

// NOTE: currently unused
export function isPunctuation(chr) {
  return chr === '.' || chr === ',' || chr === '!' || chr === '?';
}

const urlRegex = /^https?:\/\/([^\s]+\.[^\s]+$|localhost)/;
export function isLink(word) {
  return urlRegex.test(word);
}

export function mimetypeLookup(filename) {
  const parts = filename.split('.');
  const extension = parts.length > 1 ? parts[parts.length - 1] : '';
  const extensionLookup = {
    'json': 'application/json',
    'txt': 'text/plain',
    '': 'text/plain',
  };
  return extensionLookup[extension.toLowerCase()];
}

export function scrollDiv($elem, amount) {
  // # animate.  seems to not actually be great though
  // $elem.stop().animate({
  //     scrollTop: $elem[0].scrollTop + amount
  // }, 50)
  return $elem.scrollTop($elem.scrollTop() + amount);
}

export function isScrolledIntoView(elem, container) {
  const $elem = $(elem);
  const $container = $(container);

  const docViewTop = $container.offset().top;
  const docViewBottom = docViewTop + $container.outerHeight();

  const elemTop = $elem.offset().top;
  const elemBottom = elemTop + $elem.height();

  return ((elemBottom <= docViewBottom) && (elemTop >= docViewTop));
}

export function getParameterByName(name) {
  name = name.replace(/[\[\]]/g, '\\$&');
  const regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)');
  const results = regex.exec(window.location.href);
  if (!results) { return null; }
  if (!results[2]) { return ''; }
  return decodeURIComponent(results[2].replace(/\+/g, ' '));
}
