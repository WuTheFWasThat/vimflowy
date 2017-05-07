/* Utilities for stuff related to being in the browser */
import * as $ from 'jquery';

// needed for the browser checks
declare var window: any;

// TODO: get jquery typing to work?
export function scrollDiv($elem: any, amount: number) {
  // # animate.  seems to not actually be great though
  // $elem.stop().animate({
  //     scrollTop: $elem[0].scrollTop + amount
  // }, 50)
  return $elem.scrollTop($elem.scrollTop() + amount);
}

// TODO: get jquery typing to work?
export function scrollIntoView(el: Element, $within: any, margin: number = 0) {
  const elemTop = el.getBoundingClientRect().top;
  const elemBottom = el.getBoundingClientRect().bottom;

  const top_margin = margin;
  const bottom_margin = margin + $('#bottom-bar').height();

  if (elemTop < top_margin) {
    // scroll up
    return scrollDiv($within, elemTop - top_margin);
  } else if (elemBottom > window.innerHeight - bottom_margin) {
    // scroll down
    return scrollDiv($within, elemBottom - window.innerHeight + bottom_margin);
  }
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

export function downloadFile(filename: string, content: string, mimetype: string) {
  const exportDiv = $('<a>').addClass('hidden').appendTo($('body'));
  exportDiv.attr('download', filename);
  exportDiv.attr('href', `data: ${mimetype};charset=utf-8,${encodeURIComponent(content)}`);
  exportDiv[0].click();
  exportDiv.attr('download', null as any);
  exportDiv.attr('href', null as any);
  exportDiv.remove();
}

// SEE: http://stackoverflow.com/questions/9847580/how-to-detect-safari-chrome-ie-firefox-and-opera-browser
export function isOpera(): boolean {
  return !!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0; // Opera 8.0+
}
export function isSafari(): boolean {
  return Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0; // Safari 3+
}
export function isChrome(): boolean {
  return !!window.chrome && !isOpera; // Chrome 1+
}
declare var InstallTrigger: any;
export function isFirefox(): boolean {
  return typeof InstallTrigger !== 'undefined'; // Firefox 1.0+
}

export function cancel(ev: Event) {
  ev.stopPropagation();
  ev.preventDefault();
  return false;
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

