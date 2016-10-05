/* globals window, document, localStorage, alert */

/*
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage (fall back to plain in-memory datastructures)
- initialize objects (session, settings, etc.)
- handle rendering logic
*/

import $ from 'jquery';
import React from 'react';
import ReactDOM from 'react-dom';

import * as firebase from 'firebase';
window.firebase = firebase;

import 'font-awesome/css/font-awesome.css';
import '../css/utils.sass';
import '../css/index.sass';
import '../css/view.sass';
import '../css/themes/default.sass';
import '../css/themes/dark.sass';
import '../css/themes/solarized_dark.sass';
import '../css/themes/solarized_light.sass';

import * as constants from './constants';
import * as errors from './errors';
import * as utils from './utils';
import logger from './logger';

import * as Modes from './modes';
import KeyEmitter from './keyEmitter';
import KeyHandler from './keyHandler';
import * as DataStore from './datastore';
import Document from './document';
import Settings from './settings';
import { PluginsManager } from './plugins';
import Path from './path';
import Session from './session';

import keyDefinitions from './keyDefinitions';
// load actual definitions
import './definitions';
// load all plugins
import '../../plugins';
import KeyBindings from './keyBindings';

import AppComponent from './components/app.jsx';

function scrollIntoView(el, $within) {
  const elemTop = el.getBoundingClientRect().top;
  const elemBottom = el.getBoundingClientRect().bottom;

  const margin = 50;
  const top_margin = margin;
  const bottom_margin = margin + $('#bottom-bar').height();

  if (elemTop < top_margin) {
    // scroll up
    return utils.scrollDiv($within, elemTop - top_margin);
  } else if (elemBottom > window.innerHeight - bottom_margin) {
    // scroll down
    return utils.scrollDiv($within,
                           elemBottom - window.innerHeight + bottom_margin);
  }
}

function downloadFile(filename, mimetype, content) {
  const exportDiv = $('#export');
  exportDiv.attr('download', filename);
  exportDiv.attr('href', `data: ${mimetype};charset=utf-8,${encodeURIComponent(content)}`);
  exportDiv[0].click();
  exportDiv.attr('download', null);
  return exportDiv.attr('href', null);
}


$(document).ready(async () => {

  const getMessageDiv = () => $('#message');
  const getMainDiv = () => $('#view');

  const docname = window.location.pathname.split('/')[1];
  if (docname !== '') { document.title = `${docname} - Vimflowy`; }

  const noLocalStorage = (typeof localStorage === 'undefined' || localStorage === null);
  let settings;
  let dataSource;
  let datastore;
  let doc;

  if (noLocalStorage) {
    alert('You need local storage support for data to be persisted!');
    settings = new Settings(new DataStore.InMemory());
    dataSource = 'inmemory';
  } else {
    settings = new Settings(new DataStore.LocalStorageLazy());
    dataSource = await settings.getSetting('dataSource', 'local');
  }

  if (dataSource === 'firebase') {
    const firebaseUrl = await settings.getSetting('firebaseUrl');
    const firebaseApiKey = await settings.getSetting('firebaseApiKey');
    datastore = new DataStore.FirebaseStore(docname, firebaseUrl, firebaseApiKey);
  } else if (dataSource === 'inmemory') {
    datastore = new DataStore.InMemory();
  } else {
    datastore = new DataStore.LocalStorageLazy(docname, true);
  }

  async function create_session(doc, to_load) {
    const changeStyle = (theme) => {
      // $('body').removeClass().addClass(theme);
      $('body').attr('id', theme);
      settings.setSetting('theme', theme);
    };
    const initialTheme = await settings.getSetting('theme');
    changeStyle(initialTheme);
    let showingKeyBindings = await settings.getSetting('showKeyBindings');

    // hotkeys and key bindings
    const initial_hotkey_settings = await settings.getSetting('hotkeys', {});
    const keyBindings = new KeyBindings(keyDefinitions, initial_hotkey_settings);

    // session
    if (!await doc.hasChildren(doc.root.row)) {
      // HACKY: should load the actual data now, but since plugins aren't enabled...
      await doc.load(constants.empty_data);
    }
    const viewRoot = Path.loadFromAncestry(await doc.store.getLastViewRoot());
    // TODO: if we ever support multi-user case, ensure last view root is valid
    let cursorPath;
    if (viewRoot.isRoot()) {
      cursorPath = (await doc.getChildren(viewRoot))[0];
    } else {
      cursorPath = viewRoot;
    }

    function getLineHeight() {
      const line_height = $('.node-text').height() || 21;
      errors.assert(line_height > 0);
      return line_height;
    }

    const session = new Session(doc, {
      bindings: keyBindings,
      settings,
      viewRoot: viewRoot,
      cursorPath: cursorPath,
      showMessage: (() => {
        let messageDivTimeout = null;
        return (message, options = {}) => {
          const $messageDiv = getMessageDiv();
          if (options.time === undefined) { options.time = 5000; }
          logger.info(`Showing message: ${message}`);
          if ($messageDiv) {
            clearTimeout(messageDivTimeout);

            $messageDiv.text(message);
            if (options.text_class) {
              $messageDiv.addClass(`text-${options.text_class}`);
            }

            messageDivTimeout = setTimeout(() => {
              $messageDiv.text('');
              return $messageDiv.removeClass();
            }, options.time);
          }
        };
      })(),
      getVisiblePaths: async () => {
        const paths = [];
        $.makeArray($('.bullet')).forEach((bullet) => {
          if (!utils.isScrolledIntoView($(bullet), getMainDiv())) {
            return;
          }
          if ($(bullet).hasClass('fa-clone')) {
            return;
          }
          // NOTE: can't use $(x).data
          // http://stackoverflow.com/questions/25876274/jquery-data-not-working
          const ancestry = $(bullet).attr('data-ancestry');
          if (!ancestry) { // as far as i know, this only happens because of menu mode
            return;
          }
          const path = Path.loadFromAncestry(JSON.parse(ancestry));
          paths.push(path);
        });
        return paths;
      },
      toggleBindingsDiv: () => {
        showingKeyBindings = !showingKeyBindings;
        settings.setSetting('showKeyBindings', showingKeyBindings);
        return renderMain();
      },
      getLinesPerPage: () => {
        const line_height = getLineHeight();
        const page_height = $(document).height();
        return page_height / line_height;
      },
      downloadFile: downloadFile
    });

    // load plugins

    const pluginManager = new PluginsManager(session);
    let enabledPlugins = (await settings.getSetting('enabledPlugins')) || ['Marks'];
    if (typeof enabledPlugins.slice === 'undefined') { // for backwards compatibility
      enabledPlugins = Object.keys(enabledPlugins);
    }
    for (var i = 0; i < enabledPlugins.length; i++) {
      const plugin_name = enabledPlugins[i];
      await pluginManager.enable(plugin_name);
    }

    // load data

    if (to_load !== null) {
      await doc.load(to_load);
      // a bit hack.  without this, you can undo initial marks, for example
      session.reset_history();
      session.reset_jump_history();
    }

    const keyHandler = new KeyHandler(session, keyBindings);

    const keyEmitter = new KeyEmitter();

    // expose globals, for debugging
    window.Modes = Modes;
    window.session = session;
    window.keyHandler = keyHandler;
    window.keyEmitter = keyEmitter;
    window.keyBindings = keyBindings;

    function renderMain() {
      return new Promise((resolve) => {
        ReactDOM.render(
          <AppComponent
            onThemeChange={changeStyle}
            session={session}
            pluginManager={pluginManager}
            showingKeyBindings={showingKeyBindings}
            keyBindings={keyBindings}
            initialDataSource={dataSource}
            initialTheme={initialTheme}
            onRender={(options) => {
              const $onto = $('#view');
              logger.debug('Render called: ', options);
              setTimeout(() => {
                const cursorDiv = $('.cursor', $onto)[0];
                if (cursorDiv) {
                  scrollIntoView(cursorDiv, $onto);
                }

                clearTimeout(session.cursorBlinkTimeout);
                $onto.removeClass('animate-blink-cursor');
                session.cursorBlinkTimeout = setTimeout(
                  () => $onto.addClass('animate-blink-cursor'), 500);
              }, 100);
            }}
            onExport={() => {
              const filename = 'vimflowy_hotkeys.json';
              const content = JSON.stringify(keyBindings.hotkeys, null, 2);
              downloadFile(filename, 'application/json', content);
              session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
            }}
          />,
          $('#app')[0],
          resolve
        );
      });
    }

    renderMain().then(async () => {
      const $settingsDiv = $('#settings');
      const $mainDiv = $('#view');

      session.on('scroll', (numlines) => {
        const line_height = getLineHeight();
        utils.scrollDiv($mainDiv, line_height * numlines);
      });

      // load settings

      session.on('importFinished', renderMain);

      keyEmitter.listen();
      keyEmitter.on('keydown', (key) => {
        // NOTE: this is just a best guess... e.g. the mode could be wrong
        // problem is that we process asynchronously, but need to
        // return synchronously
        const handled = !!keyBindings.bindings[session.mode][key];

        // fire and forget
        // NOTE: could use handled_command event instead?
        keyHandler.handleKey(key).then(() => {
          renderMain();
        });
        return handled;
      });

      //###################
      // prepare dom
      //###################

      // render when ready
      $(document).ready(function() {
        session.on('modeChange', renderMain);

        keyBindings.on('applied_hotkey_settings', (hotkey_settings) => {
          settings.setSetting('hotkeys', hotkey_settings);
          renderMain();
        });

        pluginManager.on('status', renderMain);

        pluginManager.on('enabledPluginsChange', function(enabled) {
          settings.setSetting('enabledPlugins', enabled);
          renderMain();
        });

        // needed for safari
        const $pasteHack = $('#paste-hack');
        $pasteHack.focus();
        $(document).on('click', function() {
          // if settings menu is up, we don't want to blur (the dropdowns need focus)
          if ($settingsDiv.hasClass('hidden')) {
            // if user is trying to copy, we don't want to blur
            if (!window.getSelection().toString()) {
              return $pasteHack.focus();
            }
          }
        });

        $(document).on('paste', async (e) => {
          e.preventDefault();
          const text = (e.originalEvent || e).clipboardData.getData('text/plain');
          // TODO: deal with this better when there are multiple lines
          // maybe put in insert mode?
          const lines = text.split('\n');
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (i !== 0) {
              await session.newLineAtCursor();
            }
            const chars = line.split('');
            await session.addCharsAtCursor(chars);
          }
          session.save();
          renderMain();
        });
      });
    });

    return $(window).on('unload', () => {
      session.exit();
      // NOTE: this is fire and forget
    });
  }

  doc = new Document(datastore, docname);

  let to_load = null;
  if (datastore.getLastSave() === 0) {
    to_load = constants.default_data;
  }

  create_session(doc, to_load);

  Promise.onPossiblyUnhandledRejection(function(error) {
    throw error;
  });

  let shown_error_time = 0;
  window.onerror = function(msg, url, line, col, err) {
    logger.error(`Caught error: '${msg}' from  ${url}:${line}`);
    if (err) {
      logger.error('Error: ', err, err.stack);
    }

    if (err instanceof errors.DataPoisoned) {
      // no need to alert, already alerted
      return;
    }

    const t = Date.now();
    if (t - shown_error_time < 60000) {
      return;
    } else {
      shown_error_time = t;
    }

    return alert(`
      An error was caught.  Please refresh the page to avoid weird state. \n\n
      Please help out vimflowy and report the bug!
      Simply open the javascript console, save the log as debug information,
      and send it to wuthefwasthat@gmail.com with a brief description of what happened.
      \n\n
      ERROR:\n\n
      ${msg}\n\n
      ${err}\n\n
      ${err && err.stack}
    `
    );
  };
});
