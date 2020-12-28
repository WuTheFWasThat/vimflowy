/*
Initialize the main page.  Rather messy logic for a bunch of stuff:
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage (fall back to plain in-memory datastructures)
- initialize objects (session, etc.)
- handle rendering logic
*/

import $ from 'jquery';
import * as React from 'react'; // tslint:disable-line no-unused-variable
import * as ReactDOM from 'react-dom';

import 'font-awesome/css/font-awesome.min.css';
import '../css/utils.sass';
import '../css/index.sass';
import '../css/view.sass';

import * as browser_utils from './utils/browser';
import * as errors from '../../shared/utils/errors';
import logger from '../../shared/utils/logger';

import { SerializedBlock } from './types';
import * as Modes from './modes';
import { RegisterTypes } from './register';
import KeyEmitter from './keyEmitter';
import KeyHandler from './keyHandler';
import KeyMappings from './keyMappings';
import { ClientStore, DocumentStore } from './datastore';
import { SynchronousInMemory, InMemory } from '../../shared/data_backend';
import {
  BackendType, SynchronousLocalStorageBackend,
  LocalStorageBackend, FirebaseBackend, ClientSocketBackend
} from './data_backend';
import Document from './document';
import { PluginsManager } from './plugins';
import Path from './path';
import Session from './session';
import Config from './config';
import vimConfig from './configurations/vim';
import { SERVER_CONFIG } from './constants';

import keyDefinitions from './keyDefinitions';
// load actual definitions
import './definitions';
// load all plugins
import '../../plugins';
import KeyBindings from './keyBindings';

import AppComponent, { TextMessage } from './components/app';

declare const window: any; // because we attach globals for debugging

const appEl = $('#app')[0];

ReactDOM.render(
  <div style={{
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
  }}>
    <div style={{ flexGrow: 3 }}/>
    <div style={{
      textAlign: 'center',
      alignSelf: 'center',
      color: '#999',
    }}>
      <i className='fa fa-5x fa-spin fa-spinner'/>
      <p>Loading... this can take a minute the first time</p>
    </div>
    <div style={{ flexGrow: 8 }}/>
  </div>,
  appEl
);

$(document).ready(async () => {
  let docname: string = browser_utils.getParameterByName('doc') || '';
  if (docname !== '') { document.title = `${docname} - Vimflowy`; }

  // random global state.  these things should be managed by redux maybe
  let caughtErr: null | Error = null;
  let userMessage: null | TextMessage = null;
  let saveMessage: null | TextMessage = null;

  window.onerror = function(msg: string, url: string, line: number, _col: number, err: Error) {
    logger.error(`Caught error: '${msg}' from  ${url}:${line}`);
    if (err) {
      logger.error('Error: ', msg, err, err.stack, JSON.stringify(err));
      caughtErr = err;
    } else {
      logger.error('Error: ', msg, JSON.stringify(msg));
      caughtErr = new Error(msg);
    }
    renderMain(); // fire and forget
  };

  const noLocalStorage = (typeof localStorage === 'undefined' || localStorage === null);
  let clientStore: ClientStore;
  let docStore: DocumentStore;
  let backend_type: BackendType;
  let doc;

  // TODO: consider using modernizr for feature detection
  // probably also want to check flexbox support
  if (noLocalStorage) {
    alert('You need local storage support for data to be persisted!');
    clientStore = new ClientStore(new SynchronousInMemory());
    backend_type = 'inmemory';
  } else {
    clientStore = new ClientStore(new SynchronousLocalStorageBackend(), docname);
    if (SERVER_CONFIG.socketserver) {
      backend_type = 'socketserver';
    } else {
      backend_type = clientStore.getDocSetting('dataSource');
    }
  }

  const config: Config = vimConfig;

  function getLocalStore(): DocumentStore {
     return new DocumentStore(new LocalStorageBackend(docname), docname);
  }

  async function getFirebaseStore(): Promise<DocumentStore> {
    const firebaseId = clientStore.getDocSetting('firebaseId');
    const firebaseApiKey = clientStore.getDocSetting('firebaseApiKey');
    const firebaseUserEmail = clientStore.getDocSetting('firebaseUserEmail');
    const firebaseUserPassword = clientStore.getDocSetting('firebaseUserPassword');

    if (!firebaseId) {
      throw new Error('No firebase ID found');
    }
    if (!firebaseApiKey) {
      throw new Error('No firebase API key found');
    }
    const fb_backend = new FirebaseBackend(docname, firebaseId, firebaseApiKey);
    const dStore = new DocumentStore(fb_backend, docname);
    await fb_backend.init(firebaseUserEmail || '', firebaseUserPassword || '');

    logger.info(`Successfully initialized firebase connection: ${firebaseId}`);
    return dStore;
  }

  async function getSocketServerStore(): Promise<DocumentStore> {
    let socketServerHost;
    let socketServerDocument;
    let socketServerPassword;
    if (SERVER_CONFIG.socketserver) { // server is fixed!
      socketServerHost = window.location.origin.replace(/^http/, 'ws');
      socketServerDocument = docname;
      socketServerPassword = clientStore.getDocSetting('socketServerPassword');
    } else {
      socketServerHost = clientStore.getDocSetting('socketServerHost');
      socketServerDocument = clientStore.getDocSetting('socketServerDocument');
      socketServerPassword = clientStore.getDocSetting('socketServerPassword');
    }

    if (!socketServerHost) {
      throw new Error('No socket server host found');
    }
    const socket_backend = new ClientSocketBackend();
    // NOTE: we don't pass docname to DocumentStore since we want keys
    // to not have prefixes
    const dStore = new DocumentStore(socket_backend);
    while (true) {
      try {
        await socket_backend.init(
          socketServerHost, socketServerPassword || '', socketServerDocument || '');
        break;
      } catch (e) {
        if (e === 'Wrong password!') {
          socketServerPassword = prompt(
            socketServerPassword ?
              'Password incorrect!  Please try again: ' :
              'Please enter the password',
            '');
        } else {
          throw e;
        }
      }
    }
    clientStore.setDocSetting('socketServerPassword', socketServerPassword);
    logger.info(`Successfully initialized socked connection: ${socketServerHost}`);
    return dStore;
  }

  if (backend_type === 'firebase') {
    try {
      docStore = await getFirebaseStore();
    } catch (e) {
      alert(`
        Error loading firebase datastore:

        ${e.message}

        ${e.stack}

        Falling back to localStorage default.
      `);

      docStore = getLocalStore();
      backend_type = 'local';
    }
  } else if (backend_type === 'inmemory') {
    docStore = new DocumentStore(new InMemory());
  } else if (backend_type === 'socketserver') {
    try {
      docStore = await getSocketServerStore();
    } catch (e) {
      alert(`
        Error loading socket server datastore:

        ${e.message}

        ${e.stack}

        Falling back to localStorage default.
      `);

      clientStore.setDocSetting('socketServerPassword', '');
      docStore = getLocalStore();
      backend_type = 'local';
    }
  } else {
    docStore = getLocalStore();
    backend_type = 'local';
  }

  doc = new Document(docStore, docname);

  let to_load: any = null;
  if ((await docStore.getChildren(Path.rootRow())).length === 0) {
    to_load = config.getDefaultData();
  }

  let showingKeyBindings = clientStore.getClientSetting('showKeyBindings');

  doc.store.events.on('saved', () => {
    saveMessage = { message: 'Saved!', text_class: 'text-success' };
    renderMain(); // fire and forget
  });
  doc.store.events.on('unsaved', () => {
    saveMessage = { message: 'Saving....', text_class: 'text-error' };
    renderMain(); // fire and forget
  });

  // hotkeys and key bindings
  const saved_mappings = clientStore.getClientSetting('hotkeys');
  const mappings = KeyMappings.merge(config.defaultMappings, new KeyMappings(saved_mappings));
  const keyBindings = new KeyBindings(keyDefinitions, mappings);

  // session
  if (!await doc.hasChildren(doc.root.row)) {
    // HACKY: should load the actual data now, but since plugins aren't enabled...
    await doc.loadEmpty();
  }

  let viewRoot;
  if (window.location.hash.length > 1) {
    try {
      const row = parseInt(window.location.hash.slice(1), 10);
      if (await doc.isAttached(row)) {
        viewRoot = await doc.canonicalPath(row);
      }
    } catch (e) {
      logger.error(`Invalid hash: ${window.location.hash}`);
    }
  }
  if (!viewRoot) {
    viewRoot = Path.loadFromAncestry(await clientStore.getLastViewRoot());
  }
  let cursorPath;
  if (viewRoot.isRoot() || !await doc.isValidPath(viewRoot)) {
    viewRoot = Path.root();
    cursorPath = (await doc.getChildren(viewRoot))[0];
    window.location.hash = '';
  } else {
    cursorPath = viewRoot;
  }

  function getLineHeight() {
    const line_height = $('.node-text').height() || 21;
    errors.assert(line_height > 0);
    return line_height;
  }

  const session = new Session(clientStore, doc, {
    viewRoot: viewRoot,
    cursorPath: cursorPath,
    showMessage: (() => {
      let messageDivTimeout: null | number = null;
      return (message: string, options: {time?: number, text_class?: string} = {}) => {
        const { time = 5000, text_class = '' } = options;

        logger.info(`Showing message: ${message}`);

        userMessage = {
          message,
          text_class: text_class ? 'text-' + text_class : '',
        };
        renderMain(); // fire and forget

        if (messageDivTimeout !== null) {
          clearTimeout(messageDivTimeout);
        }

        if (time !== 0) {
          messageDivTimeout = window.setTimeout(() => {
            userMessage = null;
            renderMain(); // fire and forget
          }, time);
        }
      };
    })(),
    toggleBindingsDiv: () => {
      showingKeyBindings = !showingKeyBindings;
      clientStore.setClientSetting('showKeyBindings', showingKeyBindings);
      renderMain(); // fire and forget
    },
    getLinesPerPage: () => {
      const line_height = getLineHeight();
      const page_height = $(document).height() as number;
      return page_height / line_height;
    },
  });

  // load plugins

  const pluginManager = new PluginsManager(session, config, keyBindings);
  let enabledPlugins = await docStore.getSetting('enabledPlugins');
  if (typeof enabledPlugins.slice === 'undefined') { // for backwards compatibility
    enabledPlugins = Object.keys(enabledPlugins);
  }
  for (let i = 0; i < enabledPlugins.length; i++) {
    const plugin_name = enabledPlugins[i];
    await pluginManager.enable(plugin_name);
  }

  // load data
  if (to_load !== null) {
    await doc.load(to_load);
    // a bit hacky.  without this, you can undo initial marks, for example
    session.cursor.setPosition(
      (await doc.getChildren(viewRoot))[0], 0
    );
    session.reset_history();
    session.reset_jump_history();
    await renderMain();
  }

  const keyHandler = new KeyHandler(session, keyBindings);
  const keyEmitter = new KeyEmitter();

  // expose globals, for debugging
  window.Modes = Modes;
  window.session = session;
  window.logger = logger;
  window.keyHandler = keyHandler;
  window.keyEmitter = keyEmitter;
  window.keyBindings = keyBindings;

  async function renderMain() {
    await new Promise((resolve) => {
      ReactDOM.render(
        <AppComponent
          error={caughtErr}
          message={userMessage}
          saveMessage={saveMessage}
          config={config}
          session={session}
          pluginManager={pluginManager}
          showingKeyBindings={showingKeyBindings}
          keyBindings={keyBindings}
          initialBackendType={backend_type}
        /> as any, // TODO
        appEl,
        resolve as any // TODO
      );
    });

    const cursorDiv = $('#view .cursor')[0];
    if (cursorDiv) {
      browser_utils.scrollIntoView(cursorDiv, $('#view'), 50);
    }
  }
  window.renderMain = renderMain;

  await renderMain();

  session.on('scroll', (numlines) => {
    const line_height = getLineHeight();
    browser_utils.scrollDiv($('#view'), line_height * numlines);
  });

  session.on('yank', (info) => {
    if (clientStore.getClientSetting('copyToClipboard')) {
      let content: string, richContent: string;
      if (info.type === RegisterTypes.CHARS) {
        content = info.saved.join('');
        richContent = info.saved.join('');
      } else if (info.type === RegisterTypes.SERIALIZED_ROWS) {
        const formatted = clientStore.getClientSetting('formattedCopy');
        const contents: Array<string> = [];
        const richContents: Array<string> = ['<ul>'];
        const cache: {[id: number]: SerializedBlock} = {};
        const recurse = (p: any, depth: number) => {
          if (typeof p === 'string') { throw new Error('Expected non-pretty serialization');
          } else if (p.clone) { p = cache[p.clone];
          } else { cache[p.id] = p; } // in case it's cloned

          if (formatted) { contents.push(' '.repeat(depth * 4) + (p.collapsed ? '+ ' : '- ') + p.text);
          } else { contents.push(p.text); }
          richContents.push('<li>' + p.text + '</li>');

          if (p.collapsed || !p.children) { return; }
          richContents.push('<ul>');
          p.children.forEach((child: SerializedBlock) => recurse(child, depth + 1));
          richContents.push('</ul>');
        };
        info.saved.forEach((p: SerializedBlock) => recurse(p, 0));
        content = contents.join('\n');
        richContents.push('</ul>');
        if (contents.length <= 1) { richContent = content; } else {
          richContent = richContents.join('\n');
        }
      } else if (info.type === RegisterTypes.CLONED_ROWS) {
        // For now, this does not copy, for efficiency reasons
        return;
      } else {
        throw Error(`Unexpected yank with invalid info ${info}`);
      }

      copyToClipboard(content, richContent);
      // session.showMessage('Copied to clipboard!'
      //   + (content.length > 10 ? content.substr(0, 10) + '...' : content));
    }
  });

  session.on('importFinished', renderMain); // fire and forget

  session.on('changeViewRoot', async (path: Path) => {
    await clientStore.setLastViewRoot(path.getAncestry());
    window.location.hash = `#${path.row}`;
  });

  keyEmitter.listen();
  keyEmitter.on('keydown', (key) => {
    keyHandler.queueKey(key);
    // NOTE: this is just a best guess... e.g. the mode could be wrong
    // problem is that we process asynchronously, but need to return synchronously
    return keyBindings.bindings[session.mode].getKey(key) != null;
  });

  keyHandler.on('handledKey', renderMain); // fire and forget

  session.on('modeChange', renderMain); // fire and forget

  keyBindings.on('applied_hotkey_settings', (hotkey_settings) => {
    clientStore.setClientSetting('hotkeys', hotkey_settings);
    renderMain(); // fire and forget
  });

  pluginManager.on('status', renderMain); // fire and forget

  pluginManager.on('enabledPluginsChange', function(enabled) {
    docStore.setSetting('enabledPlugins', enabled);
    renderMain(); // fire and forget
  });

  // needed for safari
  const $pasteHack = $('#paste-hack');
  $pasteHack.focus();
  $(document).on('click', function() {
    // if settings menu is up, we don't want to blur (the dropdowns need focus)
    if (session.mode === 'SETTINGS') { return; }
    // if user is trying to copy, we don't want to blur
    if (window.getSelection().toString()) { return; }
    $pasteHack.focus();
  });

  $(document).on('paste', async (e) => {
    if (session.mode === 'SETTINGS') { return; }

    e.preventDefault();
    let text: string = ((e.originalEvent || e) as any).clipboardData.getData('text/plain');
    text = text.replace(/(?:\r)/g, '');  // Remove \r (Carriage Return) from each line
    await keyHandler.queue(async () => {
      // TODO: deal with this better when there are multiple lines
      // maybe put in insert mode?
      const lines = text.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (i !== 0) {
          await session.newLineAtCursor();
        }
        await session.addCharsAtCursor(line.split(''));
      }
      session.save();
    });
    renderMain(); // fire and forget
  });

  $(window).on('unload', () => {
    session.exit(); // fire and forget
  });

  // NOTE: problem is that this is very slow!
  //   Also, to make it work, needs bluebird
  // (Promise as any).onPossiblyUnhandledRejection(function(error) {
  //   throw error;
  // });
});

function copyToClipboard(text: string, richText?: string) {
  // https://stackoverflow.com/a/33928558/5937230

  // https://stackoverflow.com/questions/23934656/javascript-copy-rich-text-contents-to-clipboard
  function listener(e: ClipboardEvent) {
    if (!e.clipboardData) {
      return;
    }
    if (richText) {
      e.clipboardData.setData('text/html', richText);
    }
    e.clipboardData.setData('text/plain', text);
    e.preventDefault();
  }

  if (window.clipboardData && window.clipboardData.setData) {
    // IE specific code path to prevent textarea being shown while dialog is visible.
    return window.clipboardData.setData('Text', text);
  } else if (document.queryCommandSupported && document.queryCommandSupported('copy')) {
    const textarea = document.createElement('textarea');
    textarea.textContent = text;
    textarea.style.position = 'fixed';  // Prevent scrolling to bottom of page in MS Edge.
    document.body.appendChild(textarea);
    textarea.select();


    try {
      document.addEventListener('copy', listener);
      return document.execCommand('copy');  // Security exception may be thrown by some browsers.
    } catch (ex) {
      console.warn('Copy to clipboard failed.', ex);
      return false;
    } finally {
      document.body.removeChild(textarea);
      document.removeEventListener('copy', listener);
    }
  }
  return false;
}
