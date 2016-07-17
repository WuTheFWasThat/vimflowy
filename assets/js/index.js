/* globals $, window, document, FileReader, chrome, localStorage, alert */

/*
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage/chrome storage (fall back to plain in-memory datastructures)
- initialize objects (session, settings, etc.) with relevant divs
*/

import * as constants from './constants';
import * as errors from './errors';
import * as utils from './utils';
import * as Logger from './logger';

import * as Modes from './modes';
import KeyEmitter from './keyEmitter';
import KeyHandler from './keyHandler';
import * as DataStore from './datastore';
import Document from './document';
import Settings from './settings';
import { PluginsManager } from './plugins';
import Session from './session';
import Render from './render';

import keyDefinitions from './keyDefinitions';
// load all definitions
require('./definitions/*.js', {mode: 'expand'});
// load all plugins
require('../../plugins/**/*.js', {mode: 'expand'});
import KeyBindings from './keyBindings';


let $keybindingsDiv = $('#keybindings');
let $settingsDiv = $('#settings');
let $modeDiv = $('#mode');

let docname = window.location.pathname.split('/')[1];

let changeStyle = theme => $('body').attr('id', theme);

let create_session = function(doc, to_load) {

  //###################
  // Settings
  //###################

  let settings = new Settings(doc.store, {mainDiv: $settingsDiv});

  changeStyle((settings.getSetting('theme')));
  $settingsDiv.find('.theme-selection').val((settings.getSetting('theme')));
  $settingsDiv.find('.theme-selection').on('input', function(/*e*/) {
    let theme = this.value;
    settings.setSetting('theme', theme);
    return changeStyle(theme);
  }
  );

  $keybindingsDiv.toggleClass('active', (settings.getSetting('showKeyBindings')));

  //###################
  // hotkeys and key bindings
  //###################

  let hotkey_settings = settings.getSetting('hotkeys');
  let key_bindings = new KeyBindings(keyDefinitions, hotkey_settings);

  //###################
  // session
  //###################

  let session = new Session(doc, {
    bindings: key_bindings,
    settings,
    mainDiv: $('#view'),
    messageDiv: $('#message'),
    menuDiv: $('#menu')
  });

  key_bindings.on('applied_hotkey_settings', function(hotkey_settings) {
    settings.setSetting('hotkeys', hotkey_settings);
    Render.renderHotkeysTable(key_bindings);
    return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
  });

  let render_mode_info = function(mode) {
    Render.renderModeTable(key_bindings, mode, $keybindingsDiv);
    return $modeDiv.text((Modes.getMode(mode)).name);
  };

  render_mode_info(session.mode);
  session.on('modeChange', (oldmode, newmode) => render_mode_info(newmode)
  );

  session.on('toggleBindingsDiv', function() {
    $keybindingsDiv.toggleClass('active');
    doc.store.setSetting('showKeyBindings', $keybindingsDiv.hasClass('active'));
    return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
  }
  );

  //###################
  // plugins
  //###################

  let pluginManager = new PluginsManager(session, $('#plugins'));
  let enabledPlugins = (settings.getSetting('enabledPlugins')) || ['Marks'];
  for (let i = 0; i < enabledPlugins.length; i++) {
    let plugin_name = enabledPlugins[i];
    pluginManager.enable(plugin_name);
  }
  Render.renderPlugins(pluginManager);

  pluginManager.on('status', () => Render.renderPlugins(pluginManager)
  );

  pluginManager.on('enabledPluginsChange', function(enabled) {
    settings.setSetting('enabledPlugins', enabled);
    Render.renderPlugins(pluginManager);
    Render.renderSession(session);
    // refresh hotkeys, if any new ones were added/removed
    Render.renderHotkeysTable(session.bindings);
    return Render.renderModeTable(session.bindings, session.mode, $keybindingsDiv);
  }
  );

  //###################
  // load data
  //###################

  if (to_load !== null) {
    doc.load(to_load);
    // a bit hack.  without this, you can undo initial marks, for example
    session.reset_history();
    session.reset_jump_history();
  }

  //###################
  // prepare dom
  //###################

  // render when ready
  $(document).ready(function() {
    if (docname !== '') { document.title = `${docname} - Vimflowy`; }
    return Render.renderSession(session);
  });

  let key_handler = new KeyHandler(session, key_bindings);

  let key_emitter = new KeyEmitter();
  key_emitter.listen();
  key_emitter.on('keydown', function(key) {
    let handled = key_handler.handleKey(key);
    if (handled) {
      Render.renderSession(session);
    }
    return handled;
  }
  );

  session.on('importFinished', () => Render.renderSession(session)
  );

  // expose globals, for debugging
  window.Modes = Modes;
  window.session = session;
  window.key_handler = key_handler;
  window.key_emitter = key_emitter;
  window.key_bindings = key_bindings;

  $(document).ready(function() {
    // needed for safari
    let $pasteHack = $('#paste-hack');
    $pasteHack.focus();
    $(document).on('click', function() {
      // if settings menu is up, we don't want to blur (the dropdowns need focus)
      if ($settingsDiv.hasClass('hidden')) {
        // if user is trying to copy, we don't want to blur
        if (!window.getSelection().toString()) {
          return $pasteHack.focus();
        }
      }
    }
    );

    $(document).on('paste', function(e) {
      e.preventDefault();
      let text = (e.originalEvent || e).clipboardData.getData('text/plain');
      // TODO: deal with this better when there are multiple lines
      // maybe put in insert mode?
      let lines = text.split('\n');
      for (let i = 0; i < lines.length; i++) {
        let line = lines[i];
        if (i !== 0) {
          session.newLineAtCursor();
        }
        let chars = line.split('');
        session.addCharsAtCursor(chars);
      }
      Render.renderSession(session);
      return session.save();
    }
    );

    $('#settings-link').click(function() {
      if (session.mode === Modes.modes.SETTINGS) {
        return session.setMode(Modes.modes.NORMAL);
      } else {
        return session.setMode(Modes.modes.SETTINGS);
      }
    });

    $('#settings-nav li').click(function(e) {
      let tab = ($(e.target).data('tab'));
      $settingsDiv.find('.tabs > li').removeClass('active');
      $settingsDiv.find('.tab-pane').removeClass('active');
      $settingsDiv.find(`.tabs > li[data-tab=${tab}]`).addClass('active');
      return $settingsDiv.find(`.tab-pane#${tab}`).addClass('active');
    });

    let load_file = function(filesDiv, cb) {
      let file = filesDiv.files[0];
      if (!(file != null)) {
        return cb('No file selected for import!');
      }
      session.showMessage('Reading in file...');
      let reader = new FileReader();
      reader.readAsText(file, 'UTF-8');
      reader.onload = function(evt) {
        let content = evt.target.result;
        return cb(null, content, file.name);
      };
      return reader.onerror = function(evt) {
        cb('Import failed due to file-reading issue');
        return Logger.logger.error('Import Error', evt);
      };
    };

    let download_file = function(filename, mimetype, content) {
      let exportDiv = $('#export');
      exportDiv.attr('download', filename);
      exportDiv.attr('href', `data: ${mimetype};charset=utf-8,${encodeURIComponent(content)}`);
      exportDiv[0].click();
      exportDiv.attr('download', null);
      return exportDiv.attr('href', null);
    };

    $('#hotkeys_import').click(() =>
      load_file($('#hotkeys_file_input')[0], function(err, content) {
        if (err) { return session.showMessage(err, {text_class: 'error'}); }
        try {
          hotkey_settings = JSON.parse(content);
        } catch (e) {
          return session.showMessage(`Failed to parse JSON: ${e}`, {text_class: 'error'});
        }
        err = key_bindings.apply_hotkey_settings(hotkey_settings);
        if (err) {
          return session.showMessage(err, {text_class: 'error'});
        } else {
          return session.showMessage('Loaded new hotkey settings!', {text_class: 'success'});
        }
      }
      )
    );

    $('#hotkeys_export').click(function() {
      let filename = 'vimflowy_hotkeys.json';
      let content = JSON.stringify(key_bindings.hotkeys, null, 2);
      download_file(filename, 'application/json', content);
      return session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
    });

    $('#hotkeys_default').click(function() {
      key_bindings.apply_default_hotkey_settings();
      return session.showMessage('Loaded defaults!', {text_class: 'success'});
    });

    $('#data_import').click(() =>
      load_file($('#import-file :file')[0], function(err, content, filename) {
        if (err) { return session.showMessage(err, {text_class: 'error'}); }
        let mimetype = utils.mimetypeLookup(filename);
        if (session.importContent(content, mimetype)) {
          session.showMessage('Imported!', {text_class: 'success'});
          return session.setMode(Modes.modes.NORMAL);
        } else {
          return session.showMessage('Import failed due to parsing issue', {text_class: 'error'});
        }
      }
      )
    );

    let export_type = function(type) {
      session.showMessage('Exporting...');
      let filename = docname === '' ? `vimflowy.${type}` : `${docname}.${type}`;
      // Infer mimetype from file extension
      let mimetype = utils.mimetypeLookup(filename);
      let content = session.exportContent(mimetype);
      download_file(filename, mimetype, content);
      return session.showMessage(`Exported to ${filename}!`, {text_class: 'success'});
    };

    $('#data_export_json').click((export_type.bind(this, 'json')));
    return $('#data_export_plain').click((export_type.bind(this, 'txt')));
  });

  return $(window).unload(() => session.exit());
};


let datastore;
let doc;

if ((typeof chrome !== 'undefined') && chrome.storage && chrome.storage.sync) {
  Logger.logger.info('using chrome storage');

  // TODO
  // datastore = new DataStore.ChromeStorageLazy

  datastore = new DataStore.InMemory();
  doc = new Document(datastore);
  chrome.storage.sync.get('save', function(results) {
    create_session(doc, (results.save || constants.default_data));

    // save every 5 seconds
    return setInterval((() =>
      chrome.storage.sync.set({
        'save': doc.serialize()
      }, () =>
        // TODO have whether saved visualized
        Logger.logger.info('Saved')

      )
    ), 5000);
  }
  );

} else if (typeof localStorage !== 'undefined' && localStorage !== null) {
  datastore = new DataStore.LocalStorageLazy(docname);
  doc = new Document(datastore);

  let to_load = null;
  if ((datastore.getLastSave()) === 0) {
    to_load = constants.default_data;
  }

  create_session(doc, to_load);
} else {
  alert('You need local storage support for data to be persisted!');
  datastore = new DataStore.InMemory;
  doc = new Document(datastore);
  create_session(doc, constants.default_data);
}

window.onerror = function(msg, url, line, col, err) {
  Logger.logger.error(`Caught error: '${msg}' from  ${url}:${line}`);
  if (err !== undefined) {
    Logger.logger.error('Error: ', err, err.stack);
  }

  if (err instanceof errors.DataPoisoned) {
    // no need to alert, already alerted
    return;
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
    ${err.stack}
  `
  );
};
