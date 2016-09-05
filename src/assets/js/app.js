/* globals window, document, FileReader, localStorage, alert */

/*
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage (fall back to plain in-memory datastructures)
- initialize objects (session, settings, etc.) with relevant divs
*/

// TODO: use react more properly
//      - get rid of div options (i.e. mainDiv, etc)

import $ from 'jquery';
/* eslint-disable no-unused-vars */
import React from 'react';
/* eslint-enable no-unused-vars */
import ReactDOM from 'react-dom';

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
import * as Render from './render';

import keyDefinitions from './keyDefinitions';
// load actual definitions
import './definitions';
// load all plugins
import '../../plugins';
import KeyBindings from './keyBindings';

$(document).ready(function() {
  ReactDOM.render(
    <div>
      {/* hack for firefox paste */}
      <div id="paste-hack" contentEditable="true" className="offscreen">
      </div>

      <div id="contents">
        <div id="menu" className="hidden"></div>
        <div id="view"></div>
        <div id="keybindings" className="theme-bg-secondary"></div>
      </div>

      <div id="settings" className="hidden theme-bg-primary">
        {/* NOTE: settings-nav must have theme as well so that inherit works for tabs*/}
        <ul id="settings-nav" className="tabs theme-bg-primary">
          <li data-tab="main-settings" className="theme-trim theme-bg-secondary active">
            Settings
          </li>
          <li data-tab="hotkeys" className="theme-trim theme-bg-secondary">
            Hotkeys
          </li>
          <li data-tab="plugins" className="theme-trim theme-bg-secondary">
            Plugins
          </li>
        </ul>

        <div id="main-settings" className="tab-pane active">
          <div className="settings-header theme-bg-secondary theme-trim">
            Visual Theme
          </div>
          <div className="settings-content">
            <select className="theme-selection" defaultValue={'default-theme'}>
              <option value="default-theme">
                Default
              </option>
              <option value="dark-theme">
                Dark
              </option>
              <option value="solarized_dark-theme">
                Solarized Dark
              </option>
              <option value="solarized_light-theme">
                Solarized Light
              </option>
            </select>
          </div>
          <div className="settings-header theme-bg-secondary theme-trim">
            Export
          </div>
          <div className="settings-content">
            <table>
              <tr>
                <td>
                  <div id="data_export_json" className="btn theme-bg-secondary theme-trim">
                    Export as JSON
                  </div>
                </td>
                <td>
                  Best for vimflowy backups, re-imports preserving all features.
                </td>
              </tr>
              <tr>
                <td>
                  <div id="data_export_plain" className="btn theme-bg-secondary theme-trim">
                    Export as plaintext
                  </div>
                </td>
                <td>
                  Workflowy compatible, but does not support some features, e.g. marks and clones
                </td>
              </tr>
            </table>
          </div>
          <div className="settings-header theme-bg-secondary theme-trim">
            Import
          </div>
          <div className="settings-content">
            <div id="import-file">
              <input type="file" name="import-file" style={{maxWidth:'75%'}}/>
              <div id="data_import" style={{float:'right'}} className="btn theme-bg-secondary theme-trim">
                Import!
              </div>
            </div>
          </div>
          <div className="settings-header theme-bg-secondary theme-trim">
            Info
          </div>
          <div className="settings-content">
            For more info, or to contact the maintainers, please visit
            <a href="https://github.com/WuTheFWasThat/vimflowy" className="theme-text-link">
              the github website
            </a>.
          </div>
        </div>
        <div id="hotkeys" className="tab-pane">
          <div className="settings-content">
            <div id="hotkey-actions" className="clearfix">
              <div id="hotkeys_export" style={{float:'left'}} className="btn theme-bg-secondary theme-trim">
                Export as file
              </div>
              <div id="hotkeys_default" style={{float:'left'}} className="btn theme-bg-secondary theme-trim">
                Load defaults
              </div>
              <div id="hotkeys_import" style={{float:'left'}} className="btn theme-bg-secondary theme-trim">
                Import from file
              </div>
              <input id="hotkeys_file_input" type="file" name="hotkeys-file" style={{float:'left'}}/>
            </div>
            <div id="hotkey-edit">
              <div id="hotkey-edit-normal">
              </div>
              <div id="hotkey-edit-insert">
              </div>
            </div>
          </div>
        </div>
        <div id="plugins" className="tab-pane">
          <p>
            Plugin system has not loaded.
          </p>
        </div>
      </div>

      <div id="bottom-bar" className="theme-bg-primary theme-trim">
        <a id="settings-link" className="center theme-bg-secondary">
          <div id="settings-open">
            <span style={{marginRight:10}} className="fa fa-cog">
            </span>
            <span>Settings
            </span>
          </div>
          <div id="settings-close" className="hidden">
            <span style={{marginRight:10}} className="fa fa-arrow-left">
            </span>
            <span>
              Back
            </span>
          </div>
        </a>
        <div id="message">
        </div>
        <div id="mode" className="center theme-bg-secondary">
        </div>
      </div>

      <a id="export" className="hidden"> </a>
    </div>
    ,
    $('#app')[0]
  );

  const $keybindingsDiv = $('#keybindings');
  const $settingsDiv = $('#settings');
  const $modeDiv = $('#mode');
  const $messageDiv = $('#message');
  const $pluginsDiv = $('#plugins');

  const docname = window.location.pathname.split('/')[1];

  const changeStyle = theme => $('body').attr('id', theme);
  // const changeStyle = theme => $('body').removeClass().addClass(theme);

  async function create_session(doc, to_load) {

    //###################
    // Settings
    //###################

    const settings = new Settings(doc.store);

    const theme = await settings.getSetting('theme');
    changeStyle(theme);
    $settingsDiv.find('.theme-selection').val(theme);
    $settingsDiv.find('.theme-selection').on('input', function(/*e*/) {
      const theme = this.value;
      settings.setSetting('theme', theme);
      return changeStyle(theme);
    });

    const showingKeyBindings = await settings.getSetting('showKeyBindings');
    $keybindingsDiv.toggleClass('active', showingKeyBindings);

    //###################
    // hotkeys and key bindings
    //###################

    const initial_hotkey_settings = await settings.getSetting('hotkeys', {});
    const key_bindings = new KeyBindings(keyDefinitions, initial_hotkey_settings);

    //###################
    // session
    //###################

    if (!doc.hasChildren(doc.root.row)) {
      // HACKY: should load the actual data now, but since plugins aren't enabled...
      doc.load(constants.empty_data);
    }

    const viewRoot = Path.loadFromAncestry(doc.store.getLastViewRoot());

    // TODO: if we ever support multi-user case, ensure last view root is valid
    let cursorPath;
    if (viewRoot.isRoot()) {
      cursorPath = doc.getChildren(viewRoot)[0];
    } else {
      cursorPath = viewRoot;
    }

    let messageDivTimeout = null;

    const session = new Session(doc, {
      bindings: key_bindings,
      settings,
      mainDiv: $('#view'),
      menuDiv: $('#menu'),
      viewRoot: viewRoot,
      cursorPath: cursorPath,
      showMessage: (message, options = {}) => {
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
      }

    });

    //###################
    // plugins
    //###################

    const pluginManager = new PluginsManager(session);
    let enabledPlugins = (await settings.getSetting('enabledPlugins')) || ['Marks'];
    if (typeof enabledPlugins.slice === 'undefined') { // for backwards compatibility
      enabledPlugins = Object.keys(enabledPlugins);
    }
    enabledPlugins.forEach((plugin_name) => pluginManager.enable(plugin_name));

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
      // render mode
      const render_mode_info = function(mode) {
        Render.renderModeTable(key_bindings, mode, $keybindingsDiv);
        return $modeDiv.text(Modes.getMode(mode).name);
      };

      render_mode_info(session.mode);
      session.on('modeChange', (oldmode, newmode) => {
        render_mode_info(newmode);

        $settingsDiv.toggleClass('hidden', newmode !== Modes.modes.SETTINGS);
        $('#settings-open').toggleClass('hidden', newmode === Modes.modes.SETTINGS);
        $('#settings-close').toggleClass('hidden', newmode !== Modes.modes.SETTINGS);
      });

      const render_hotkey_settings = (hotkey_settings) => {
        settings.setSetting('hotkeys', hotkey_settings);
        Render.renderHotkeysTable(key_bindings);
        return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
      };
      render_hotkey_settings(initial_hotkey_settings);
      key_bindings.on('applied_hotkey_settings', render_hotkey_settings);

      session.on('toggleBindingsDiv', function() {
        $keybindingsDiv.toggleClass('active');
        doc.store.setSetting('showKeyBindings', $keybindingsDiv.hasClass('active'));
        return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
      });

      Render.renderPlugins($pluginsDiv, pluginManager);
      pluginManager.on('status', () => Render.renderPlugins($pluginsDiv, pluginManager));

      pluginManager.on('enabledPluginsChange', function(enabled) {
        settings.setSetting('enabledPlugins', enabled);
        Render.renderPlugins($pluginsDiv, pluginManager);
        Render.renderSession(session);
        // refresh hotkeys, if any new ones were added/removed
        Render.renderHotkeysTable(session.bindings);
        return Render.renderModeTable(session.bindings, session.mode, $keybindingsDiv);
      });

      if (docname !== '') { document.title = `${docname} - Vimflowy`; }
      return Render.renderSession(session);
    });

    const key_handler = new KeyHandler(session, key_bindings);

    const key_emitter = new KeyEmitter();
    key_emitter.listen();
    key_emitter.on('keydown', (key) => {
      // NOTE: this is just a best guess... e.g. the mode could be wrong
      // problem is that we process asynchronously, but need to
      // return synchronously
      const handled = !!key_bindings.bindings[session.mode][key];

      // fire and forget
      key_handler.handleKey(key).then(() => {
        Render.renderSession(session);
      });
      return handled;
    });

    session.on('importFinished', () => Render.renderSession(session));

    // expose globals, for debugging
    window.Modes = Modes;
    window.session = session;
    window.key_handler = key_handler;
    window.key_emitter = key_emitter;
    window.key_bindings = key_bindings;

    $(document).ready(function() {
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
          session.addCharsAtCursor(chars);
        }
        Render.renderSession(session);
        session.save();
      });

      $('#settings-link').click(async function() {
        if (session.mode === Modes.modes.SETTINGS) {
          await session.setMode(Modes.modes.NORMAL);
        } else {
          await session.setMode(Modes.modes.SETTINGS);
        }
      });

      $('#settings-nav li').click(function(e) {
        const tab = $(e.target).data('tab');
        $settingsDiv.find('.tabs > li').removeClass('active');
        $settingsDiv.find('.tab-pane').removeClass('active');
        $settingsDiv.find(`.tabs > li[data-tab=${tab}]`).addClass('active');
        return $settingsDiv.find(`.tab-pane#${tab}`).addClass('active');
      });

      const load_file = function(filesDiv, cb) {
        const file = filesDiv.files[0];
        if (!file) {
          return cb('No file selected for import!');
        }
        session.showMessage('Reading in file...');
        const reader = new FileReader();
        reader.readAsText(file, 'UTF-8');
        reader.onload = function(evt) {
          const content = evt.target.result;
          return cb(null, content, file.name);
        };
        return reader.onerror = function(evt) {
          cb('Import failed due to file-reading issue');
          return logger.error('Import Error', evt);
        };
      };

      $('#hotkeys_import').click(() => {
        load_file($('#hotkeys_file_input')[0], function(err, content) {
          if (err) { return session.showMessage(err, {text_class: 'error'}); }
          let hotkey_settings;
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
        });
      });

      $('#hotkeys_export').click(function() {
        const filename = 'vimflowy_hotkeys.json';
        const content = JSON.stringify(key_bindings.hotkeys, null, 2);
        utils.download_file(filename, 'application/json', content);
        return session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
      });

      $('#hotkeys_default').click(function() {
        key_bindings.apply_default_hotkey_settings();
        return session.showMessage('Loaded defaults!', {text_class: 'success'});
      });

      $('#data_import').click(() => {
        load_file($('#import-file :file')[0], async (err, content, filename) => {
          if (err) { return session.showMessage(err, {text_class: 'error'}); }
          const mimetype = utils.mimetypeLookup(filename);
          if (await session.importContent(content, mimetype)) {
            session.showMessage('Imported!', {text_class: 'success'});
            await session.setMode(Modes.modes.NORMAL);
          } else {
            session.showMessage('Import failed due to parsing issue', {text_class: 'error'});
          }
        });
      });

      $('#data_export_json').click(() => session.exportFile('json'));
      $('#data_export_plain').click(() => session.exportFile('txt'));
    });

    return $(window).on('unload', () => session.exit());
  };

  let datastore;
  let doc;

  if (typeof localStorage !== 'undefined' && localStorage !== null) {
    datastore = new DataStore.LocalStorageLazy(docname);
    doc = new Document(datastore, docname);

    let to_load = null;
    if (datastore.getLastSave() === 0) {
      to_load = constants.default_data;
    }

    create_session(doc, to_load);
  } else {
    alert('You need local storage support for data to be persisted!');
    datastore = new DataStore.InMemory;
    doc = new Document(datastore, docname);
    create_session(doc, constants.default_data);
  }

  window.onerror = function(msg, url, line, col, err) {
    logger.error(`Caught error: '${msg}' from  ${url}:${line}`);
    if (err !== undefined) {
      logger.error('Error: ', err, err.stack);
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
});
