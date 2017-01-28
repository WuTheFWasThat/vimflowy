import React from 'react';
import _ from 'lodash';

import * as utils from '../utils';
import logger from '../logger';
import { MODES } from '../modes';

import Settings from '../settings';
import Session from '../session';
import Config from '../config';
import KeyBindings from '../keyBindings';
import KeyMappings from '../keyMappings';
import { PluginsManager } from '../plugins';
import { DataSource } from '../datastore';

import HotkeysTableComponent from './hotkeysTable';
import PluginsTableComponent from './pluginTable';
import DataStoreSettingsComponent from './settings/dataStore';
import FileInput from './fileInput';

enum TABS {
  MAIN,
  HOTKEYS,
  PLUGIN,
};

type Props = {
  session: Session;
  settings: Settings;
  config: Config;
  keyBindings: KeyBindings;
  pluginManager: PluginsManager;
  initialTheme: string;
  initialDataSource: DataSource;
  onThemeChange: (theme: string) => void;
  onExport: () => void;
};
type State = {
  currentTab: TABS,
};
export default class SettingsComponent extends React.Component<Props, State> {
  private keyBindingsUpdate: () => void;

  constructor(props: Props) {
    super(props);
    this.state = {
      currentTab: TABS.MAIN,
    };
    this.keyBindingsUpdate = () => {
      this.forceUpdate();
    };
  }

  public componentDidMount() {
    // set up listener for keybindings
    this.props.keyBindings.on('update', this.keyBindingsUpdate);
  }

  public componentWillUnmount() {
    this.props.keyBindings.off('update', this.keyBindingsUpdate);
  }

  public render() {
    const session = this.props.session;
    const keyBindings = this.props.keyBindings;

    const tabs_info = [
      {
        tab: TABS.MAIN,
        heading: 'General settings',
        div: (
          <div>
            <div className='settings-header theme-bg-secondary theme-trim'>
              Data storage
            </div>
            <div className='settings-content'>
              <DataStoreSettingsComponent
                settings={this.props.settings}
                initialDataSource={this.props.initialDataSource}
              />
            </div>

            <div className='settings-header theme-bg-secondary theme-trim'>
              Export Data
            </div>
            <div className='settings-content'>
              <table><tbody>
                <tr>
                  <td>
                    <div className='btn theme-bg-secondary theme-trim'
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
                    <div className='btn theme-bg-secondary theme-trim'
                      onClick={() => session.exportFile('txt')}>
                      Export as plaintext
                    </div>
                  </td>
                  <td>
                    Workflowy compatible.
                    Does not support all features (e.g. vimflowy's marks/clones, or workflowy's tags, etc.)
                  </td>
                </tr>
              </tbody></table>
            </div>
            <div className='settings-header theme-bg-secondary theme-trim'>
              Import Data
            </div>
            <div className='settings-content'>
              <FileInput
                onSelect={(filename) => {
                  session.showMessage(`Reading in file ${filename}...`);
                }}
                onLoad={async (filename, contents) => {
                  const mimetype = utils.mimetypeLookup(filename);
                  if (!mimetype) {
                    session.showMessage('Invalid filetype!', { time: 0 });
                    return;
                  }
                  session.showMessage('Importing contents...', { time: 0 });
                  if (await session.importContent(contents, mimetype)) {
                    session.showMessage('Imported!', {text_class: 'success'});
                    await session.setMode('NORMAL');
                  } else {
                    session.showMessage('Import failed due to parsing issue', {text_class: 'error'});
                  }
                }}
                onError={(error) => {
                  logger.error('Data file input error', error);
                  session.showMessage(`Error reading data: ${error}`, {text_class: 'error'});
                }}
              >
                <div
                  className='btn theme-bg-secondary theme-trim'
                >
                  Import from file
                </div>
              </FileInput>
            </div>

            <div className='settings-header theme-bg-secondary theme-trim'>
              Visual Theme
            </div>
            <div className='settings-content'>
              <select defaultValue={this.props.initialTheme}
                onChange={(e) => this.props.onThemeChange((e.target as HTMLSelectElement).value)}
              >
                <option value='default-theme'>
                  Default
                </option>
                <option value='dark-theme'>
                  Dark
                </option>
                <option value='solarized_dark-theme'>
                  Solarized Dark
                </option>
                <option value='solarized_light-theme'>
                  Solarized Light
                </option>
              </select>
            </div>

            <div className='settings-header theme-bg-secondary theme-trim'>
              Info
            </div>
            <div className='settings-content'>
              For more info, or to contact the maintainers, please visit
              {' '}
              <a href='https://github.com/WuTheFWasThat/vimflowy' className='theme-text-link'>
                the github website
              </a>.
            </div>
          </div>
        ),
      },
      {
        tab: TABS.HOTKEYS,
        heading: 'Hotkeys',
        div: (
          <div>
            <div className='settings-content'>
              <div className='clearfix' style={{marginBottom: 10}}>
                <div style={{float: 'left'}} className='btn theme-bg-secondary theme-trim'
                  onClick={this.props.onExport} >
                  Export as file
                </div>
                <div style={{float: 'left'}} className='btn theme-bg-secondary theme-trim'
                  onClick={() => {
                    keyBindings.setMappings(this.props.config.defaultMappings);
                    return session.showMessage('Loaded defaults!', {text_class: 'success'});
                  }}>

                  Load defaults
                </div>
                <FileInput
                  onSelect={(filename) => {
                    session.showMessage(`Reading in file ${filename}...`);
                  }}
                  onLoad={(_filename, contents) => {
                    let hotkey_settings;
                    try {
                      hotkey_settings = JSON.parse(contents);
                    } catch (e) {
                      session.showMessage(`Failed to parse JSON: ${e}`, {text_class: 'error'});
                      return;
                    }
                    const err = keyBindings.setMappings(new KeyMappings(hotkey_settings));
                    if (err) {
                      session.showMessage(err, {text_class: 'error'});
                    } else {
                      session.showMessage('Loaded new hotkey settings!', {text_class: 'success'});
                    }
                    // NOTE: this is fire and forget
                    this.props.settings.setSetting('hotkeys', hotkey_settings);
                  }}
                  onError={(error) => {
                    logger.error('Hotkeys file input error', error);
                    session.showMessage(`Error reading hotkeys: ${error}`, {text_class: 'error'});
                  }}
                  style={{float: 'left', position: 'relative'}}
                >
                  <div
                    className='btn theme-bg-secondary theme-trim'
                  >
                    Import from file
                  </div>
                </FileInput>
              </div>
              <div>
                {
                  Object.keys(MODES).map((mode) => {
                    return (
                      <div key={mode}>
                        {mode}
                        <HotkeysTableComponent
                          keyMap={keyBindings.mappings.mappings[mode]}
                          definitions={keyBindings.definitions}
                        />
                      </div>
                    );

                  })
                }
              </div>
            </div>
          </div>
        ),
      },
      {
        tab: TABS.PLUGIN,
        heading: 'Plugins',
        div: (
          <PluginsTableComponent
            pluginManager={this.props.pluginManager}
          />
        ),
      },
    ];

    return (
      <div>
        {/* NOTE: must have theme as well so that inherit works for tabs*/}
        <ul className='tabs theme-bg-primary' style={{margin: 20}}>
          {
            (() => {
              return _.map(tabs_info, (info) => {
                const isActive = info.tab === this.state.currentTab;
                const className = `theme-trim theme-bg-secondary ${isActive ? 'active' : ''}`;
                return (
                  <li className={className} key={info.tab}
                      onClick={() => this.setState({currentTab: info.tab} as State)}>
                    {info.heading}
                  </li>
                );
              });
            })()
          }
        </ul>
        {
          (() => {
            return _.map(tabs_info, (info) => {
              const isActive = info.tab === this.state.currentTab;
              return (
                <div key={info.tab}
                  className={isActive ? '' : 'hidden'} style={{padding: 20}}
                >
                  {info.div}
                </div>
              );
            });
          })()
        }

      </div>
    );
  }
}
