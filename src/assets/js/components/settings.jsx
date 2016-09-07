/* globals FileReader */
import React from 'react';
import $ from 'jquery';

import * as utils from '../utils';
import logger from '../logger';
import * as Modes from '../modes';

export default class SettingsMenu extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      key_bindings: React.PropTypes.any.isRequired,
    };
  }

  render() {
    const session = this.props.session;
    const key_bindings = this.props.key_bindings;

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

    return (
      <div>
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
                  <div className="btn theme-bg-secondary theme-trim"
                    onClick={() => session.exportFile('json')} >
                    Export as JSON
                  </div>
                </td>
                <td>
                  Best for vimflowy backups, re-imports preserving all features.
                </td>
              </tr>
              <tr>
                <td>
                  <div className="btn theme-bg-secondary theme-trim"
                    onClick={() => session.exportFile('txt')}>
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
              <div style={{float:'right'}} className="btn theme-bg-secondary theme-trim"
                onClick={() => {
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
                }}>
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
              <div style={{float:'left'}} className="btn theme-bg-secondary theme-trim"
                onClick={() => {
                  const filename = 'vimflowy_hotkeys.json';
                  const content = JSON.stringify(key_bindings.hotkeys, null, 2);
                  utils.download_file(filename, 'application/json', content);
                  return session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
                }}>
                Export as file
              </div>
              <div style={{float:'left'}} className="btn theme-bg-secondary theme-trim"
                onClick={() => {
                  key_bindings.apply_default_hotkey_settings();
                  return session.showMessage('Loaded defaults!', {text_class: 'success'});
                }}>

                Load defaults
              </div>
              <div style={{float:'left'}} className="btn theme-bg-secondary theme-trim"
                onClick={() => {
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
                }}>

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
    );
  }
}
