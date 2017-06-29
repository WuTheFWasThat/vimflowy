/*
Initialize the main page.  Rather messy logic for a bunch of stuff:
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage (fall back to plain in-memory datastructures)
- initialize objects (session, etc.)
- handle rendering logic
*/

import * as $ from 'jquery';
import * as React from 'react'; // tslint:disable-line no-unused-variable
import * as ReactDOM from 'react-dom';

import 'font-awesome/css/font-awesome.css';
import '../css/utils.sass';
import '../css/index.sass';
import '../css/view.sass';

import * as browser_utils from './utils/browser';
import * as errors from './utils/errors';
import * as fn_utils from './utils/functional';
import logger from './utils/logger';

import * as Modes from './modes';
import KeyEmitter from './keyEmitter';
import KeyHandler from './keyHandler';
import KeyMappings from './keyMappings';
import { ClientStore, DocumentStore } from './datastore';
import {
  BackendType, SynchronousInMemory, SynchronousLocalStorageBackend,
  InMemory, LocalStorageBackend, FirebaseBackend, ClientSocketBackend
} from './data_backend';
import Document from './document';
import { PluginsManager } from './plugins';
import Path from './path';
import Session from './session';
import Config from './config';
import vimConfig from './configurations/vim';

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
    backend_type = clientStore.getDocSetting('dataSource');
  }

  const config: Config = vimConfig;

  if (backend_type === 'firebase') {
    const firebaseId = clientStore.getDocSetting('firebaseId');
    const firebaseApiKey = clientStore.getDocSetting('firebaseApiKey');
    const firebaseUserEmail = clientStore.getDocSetting('firebaseUserEmail');
    const firebaseUserPassword = clientStore.getDocSetting('firebaseUserPassword');

    try {
      if (!firebaseId) {
        throw new Error('No firebase ID found');
      }
      if (!firebaseApiKey) {
        throw new Error('No firebase API key found');
      }
      const fb_backend = new FirebaseBackend(docname, firebaseId, firebaseApiKey);
      docStore = new DocumentStore(fb_backend, docname);
      await fb_backend.init(firebaseUserEmail || '', firebaseUserPassword || '');
    } catch (e) {
      alert(`
        Error loading firebase datastore:

        ${e.message}

        ${e.stack}

        Falling back to localStorage default.
      `);

      backend_type = 'local';
      docStore = new DocumentStore(new LocalStorageBackend(docname), docname);
    }
  } else if (backend_type === 'inmemory') {
    docStore = new DocumentStore(new InMemory());
  } else if (backend_type === 'socketserver') {
    const socketServerHost = clientStore.getDocSetting('socketServerHost');
    const socketServerPassword = clientStore.getDocSetting('socketServerPassword');
    const socketServerDocument = clientStore.getDocSetting('socketServerDocument');

    try {
      if (!socketServerHost) {
        throw new Error('No socket server host found');
      }
      const socket_backend = new ClientSocketBackend();
      // NOTE: we don't pass docname to DocumentStore since we want keys
      // to not have prefixes
      docStore = new DocumentStore(socket_backend);
      await socket_backend.init(
        socketServerHost, socketServerPassword || '', socketServerDocument || '');
    } catch (e) {
      alert(`
        Error loading socket server datastore:

        ${e.message}

        ${e.stack}

        Falling back to localStorage default.
      `);

      backend_type = 'local';
      docStore = new DocumentStore(new LocalStorageBackend(docname), docname);
    }
  } else {
    docStore = new DocumentStore(new LocalStorageBackend(docname), docname);
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
      const page_height = $(document).height();
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
        />,
        appEl,
        resolve
      );
    });

    // TODO: understand why this is necessary
    // weirdly happens on bitballoon but not dev mode?
    await fn_utils.timeout(100);

    const $mainDiv = $('#view');
    const cursorDiv = $('.cursor', $mainDiv)[0];
    if (cursorDiv) {
      browser_utils.scrollIntoView(cursorDiv, $mainDiv, 50);
    }
  }

  await renderMain();

  const $mainDiv = $('#view');
  session.on('scroll', (numlines) => {
    const line_height = getLineHeight();
    browser_utils.scrollDiv($mainDiv, line_height * numlines);
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
    const text: string = ((e.originalEvent || e) as any).clipboardData.getData('text/plain');
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
