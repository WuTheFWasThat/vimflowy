import * as React from 'react';
import * as _ from 'lodash';

import { ChromePicker } from 'react-color';

import * as browser_utils from '../utils/browser';
import logger from '../../../shared/utils/logger';
import { MODES } from '../modes';

import Path from '../path';
import Document from '../document';
import { DocumentStore, ClientStore } from '../datastore';
import { InMemory } from '../../../shared/data_backend';
import Session from '../session';
import Menu from '../menu';
import Config from '../config';
import KeyBindings from '../keyBindings';
import KeyMappings from '../keyMappings';
import { PluginsManager } from '../plugins';
import { BackendType } from '../data_backend';
import { Theme, getStyles, themes } from '../themes';
import { SERVER_CONFIG } from '../constants';

import SessionComponent from './session';
import SpinnerComponent from './spinner';
import MenuComponent from './menu';
import HotkeysTableComponent from './hotkeysTable';
import PluginsTableComponent from './pluginTable';
import BackendSettingsComponent from './settings/backendSettings';
import FileInput from './fileInput';
import BehaviorSettingsComponent from './settings/behaviorSettings';

enum TABS {
  DATA,
  THEME,
  BEHAVIOR,
  HOTKEYS,
  PLUGIN,
  ABOUT,
}

type Props = {
  session: Session;
  config: Config;
  keyBindings: KeyBindings;
  pluginManager: PluginsManager;
  initialBackendType: BackendType;
  onExport: () => void;
  rerenderAll: () => void;
};
type State = {
  currentTab: TABS,
  themeProperty: keyof Theme, // color theme property currently being changed
  presetTheme: string,
};

function getCurrentTheme(clientStore: ClientStore) {
  const theme: Theme = {} as Theme;
  Object.keys(themes.Default).forEach((theme_property: string) => {
    theme[theme_property as keyof Theme] = clientStore.getClientSetting(theme_property as keyof Theme);
  });
  return theme;
}

export default class SettingsComponent extends React.Component<Props, State> {
  private keyBindingsUpdate: () => void;
  private preview_session: Session | null = null;
  private preview_menu: Menu | null = null;
  private initial_theme: Theme;

  constructor(props: Props) {
    super(props);
    this.state = {
      currentTab: TABS.DATA,
      themeProperty: 'theme-bg-primary',
      presetTheme: 'Default',
    };
    this.keyBindingsUpdate = () => {
      this.forceUpdate();
    };

    this.initial_theme = getCurrentTheme(props.session.clientStore);

    (async () => {
      const preview_document = new Document(new DocumentStore(new InMemory()));
      await preview_document.load([
        { text: 'Preview document', children: [
          { text: 'Breadcrumbs', children: [
            { text: 'Header', children: [
              'This is a preview document',
              'This is a link: http://www.google.com',
              'Here is a visual selection',
              /*
              { text: 'This is marked, if marks are on', plugins: { mark: 'mark' } },
               */
            ] }
          ] }
        ] }
      ]);
      this.preview_session = new Session(
        this.props.session.clientStore, preview_document,
        { viewRoot: Path.loadFromAncestry([1, 2, 3]) }
      );
      const cursorPath = Path.loadFromAncestry([1, 2, 3, 6]);
      await this.preview_session.cursor.setPosition(cursorPath, 10);
      await this.preview_session.setMode('VISUAL');
      await this.preview_session.anchor.setPosition(cursorPath, 4);
      this.preview_session.document.cache.clear();

      function makeAccents(min: number, max: number) {
        const accents: {[key: number]: boolean} = {};
        for (let i = min; i <= max; i++) { accents[i] = true; }
        return accents;
      }

      this.preview_menu = new Menu(async (_query) => {
        return [
          {
            contents: 'Some blah result'.split(''),
            renderOptions: { accents: makeAccents(5, 8) },
            fn: () => null
          },
          {
            contents: 'Another blah result'.split(''),
            renderOptions: { accents: makeAccents(8, 11) },
            fn: () => null
          },
        ];
      });
      await this.preview_menu.session.addCharsAtCursor('blah'.split(''));
      await this.preview_menu.update();

      this.forceUpdate();
    })();
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

    const updateAll = () => {
      if (this.preview_session) {
        this.preview_session.document.cache.clear();
      }
      this.props.rerenderAll();
    };
    const applyTheme = (theme: Theme) => {
      Object.keys(theme).forEach((theme_prop: string) => {
        session.clientStore.setClientSetting(theme_prop as keyof Theme, theme[theme_prop as keyof Theme]);
      });
      updateAll();
    };

    const colorPickerRow = (name: string, theme_property: keyof Theme) => {
      const hex_color = session.clientStore.getClientSetting('theme-bg-primary');
      const rgb = parseInt(hex_color.substring(1), 16);
      // tslint:disable no-bitwise
      const r = (rgb >> 16) & 0xff;  // extract red
      const g = (rgb >>  8) & 0xff;  // extract green
      const b = (rgb >>  0) & 0xff;  // extract blue
      // tslint:enable no-bitwise
      const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b; // per ITU-R BT.709

      const style = { fontSize: 11, padding: 10, cursor: 'pointer' };
      if (theme_property === this.state.themeProperty) {
        Object.assign(style, getStyles(session.clientStore, ['theme-bg-highlight']));
      }
      return (
        <tr style={style} onClick={
          () => this.setState({themeProperty: theme_property} as State)
        }>
          <td style = {{
            width: '50px',
            border: `1px solid ${luma > 40 ? 'black' : 'white'}`,
            backgroundColor: session.clientStore.getClientSetting(theme_property)
          }}/>
          <td style={{ paddingLeft: 10 }}> {name} </td>
        </tr>
      );
    };

    const tabs_info = [
      {
        tab: TABS.DATA,
        heading: 'Data',
        div: (
          <div>
            {
              SERVER_CONFIG.socketserver ? (
                <div style={{
                  marginBottom: 20, padding: 10,
                  ...getStyles(session.clientStore, ['theme-trim-accent'])
                }}>
                  NOTE: Since you are using a Vimflowy server,
                  you can simply back up the data server-side,
                  assuming you have access to the server.
                </div>
              ) : (
                <div>
                  <div className='settings-header'
                    style={{
                      ...getStyles(session.clientStore, ['theme-bg-secondary', 'theme-trim'])
                    }}
                    >
                    Data storage
                  </div>
                  <div className='settings-content'>
                    <BackendSettingsComponent
                      clientStore={session.clientStore}
                      initialBackendType={this.props.initialBackendType}
                    />
                  </div>
                </div>
              )
            }

            <div className='settings-header'
              style={{
                ...getStyles(session.clientStore, ['theme-bg-secondary', 'theme-trim'])
              }}>
              Export Data
            </div>
            <div className='settings-content'>
              <table><tbody>
                <tr>
                  <td>
                    <div className='btn'
                      style={{
                        ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                      }}
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
                    <div className='btn'
                      style={{
                        ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                      }}
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
            <div className='settings-header'
              style={{
                ...getStyles(session.clientStore, ['theme-bg-secondary', 'theme-trim'])
              }}
              >
              Import Data
            </div>
            <div className='settings-content'>
              <FileInput
                onSelect={(filename) => {
                  session.showMessage(`Reading in file ${filename}...`);
                }}
                onLoad={async (filename, contents) => {
                  const mimetype = browser_utils.mimetypeLookup(filename);
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
                <div className='btn'
                  style={{
                    ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                  }}
                >
                  Import from file
                </div>
              </FileInput>
            </div>
          </div>
        ),
      },
      {
        tab: TABS.THEME,
        heading: 'Visual theme',
        div: (
          <div style={{ display: 'flex' }}>
            <div style={{ padding: 5, flexBasis: 1, flexGrow: 1 }}>
              <div className='settings-header'
                style={{
                  ...getStyles(session.clientStore, ['theme-bg-secondary', 'theme-trim'])
                }}
              >
                Colors
              </div>
              <div className='settings-content' style={{ display: 'flex' }}>
                <div>
                  <div style={{ paddingTop: 10 }}>
                    <table style={{ borderCollapse: 'collapse' }}><tbody>
                      {colorPickerRow('Main background color', 'theme-bg-primary')}
                      {colorPickerRow('Secondary background color', 'theme-bg-secondary')}
                      {colorPickerRow('Tertiary background color', 'theme-bg-tertiary')}
                      {colorPickerRow('Highlight background color', 'theme-bg-highlight')}
                      {colorPickerRow('Main text color', 'theme-text-primary')}
                      {colorPickerRow('Accented text color', 'theme-text-accent')}
                      {colorPickerRow('Trim color', 'theme-trim')}
                      {colorPickerRow('Accented trim color', 'theme-trim-accent')}
                      {colorPickerRow('Cursor text color', 'theme-text-cursor')}
                      {colorPickerRow('Cursor background color', 'theme-bg-cursor')}
                      {colorPickerRow('Link text color', 'theme-text-link')}
                    </tbody></table>
                  </div>

                  <div style={{padding: 10}}>
                    <span className='btn' style={{
                        ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                      }}
                      onClick={() => applyTheme(this.initial_theme) }>
                      Reset
                    </span>
                    <span className='btn' style={{
                        ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                      }} onClick={() => {
                        browser_utils.downloadFile(
                          'vimflowy_colors.json',
                          JSON.stringify(getCurrentTheme(session.clientStore)),
                          'application/json') ;
                      }}>
                      Download
                    </span>
                  </div>
                  <div>
                    <select
                      value={this.state.presetTheme}
                      onChange={(e) => {
                        const theme_name = (e.target as HTMLSelectElement).value;
                        this.setState({ presetTheme: theme_name } as State);
                      }}
                    >
                      {
                        Object.keys(themes).map((theme_name) => {
                          return (
                            <option value={theme_name} key={theme_name}>
                              {theme_name}
                            </option>
                          );
                        })
                      }
                    </select>
                    <span className='btn' style={{
                        ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                      }}
                      onClick={() => applyTheme(themes[this.state.presetTheme]) }>
                      Apply preset theme
                    </span>
                    <div style={{marginTop: 5}}>
                      <FileInput
                        onSelect={(filename) => {
                          session.showMessage(`Reading in file ${filename}...`);
                        }}
                        onLoad={(_filename, contents) => {
                          let theme;
                          try {
                            theme = JSON.parse(contents);
                          } catch (e) {
                            session.showMessage(`Failed to parse JSON: ${e}`, {text_class: 'error'});
                            return;
                          }
                          applyTheme(theme);
                        }}
                        onError={(error) => {
                          logger.error('Theme file input error', error);
                          session.showMessage(`Error reading theme: ${error}`, {text_class: 'error'});
                        }}
                        style={{float: 'left', position: 'relative'}}
                      >
                        <div className='btn'
                          style={{
                            ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                          }}
                        >
                          Import theme from file
                        </div>
                      </FileInput>
                    </div>
                  </div>
                </div>
                <div style={{ marginLeft: 50 }}>
                  <ChromePicker
                    color={ session.clientStore.getClientSetting(this.state.themeProperty) }
                    onChangeComplete={({ hex: hexColor }: any) => {
                      session.clientStore.setClientSetting(this.state.themeProperty, hexColor);
                      updateAll();
                    }}
                  />
                </div>
              </div>
            </div>
            <div style={{ padding: 5, flexBasis: 1, flexGrow: 1 }}>
              <div className='settings-header'
                style={{
                  ...getStyles(session.clientStore, ['theme-bg-secondary', 'theme-trim'])
                }}
              >
                Preview
              </div>
              <div className='settings-content' style={{
                ...getStyles(session.clientStore, ['theme-trim-accent']),
                padding: 10, marginTop: 10, pointerEvents: 'none'
              }}>
                { this.preview_session ?
                  <SessionComponent
                    session={this.preview_session}
                  /> : <SpinnerComponent/>
                }
              </div>

              <div className='settings-content' style={{
                ...getStyles(session.clientStore, ['theme-trim-accent']),
                padding: 10, marginTop: 10, pointerEvents: 'none'
              }}>
                { (this.preview_menu && this.preview_session) ?
                  <MenuComponent
                    menu={this.preview_menu}
                    session={this.preview_session}
                  /> : <SpinnerComponent/>
                }
              </div>
            </div>
          </div>
        ),
      },
      {
        tab: TABS.BEHAVIOR,
        heading: 'Behavior',
        div: (
          <div>
            {
              <div className='settings-content'>
                <BehaviorSettingsComponent
                  clientStore={session.clientStore}
                />
              </div>
            }
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
                <div className='btn'
                  style={{
                    float: 'left',
                    ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                  }}
                  onClick={this.props.onExport} >
                  Export as file
                </div>
                <div className='btn'
                  style={{
                    float: 'left',
                    ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                  }}
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
                    const mappings = new KeyMappings(hotkey_settings);
                    keyBindings.setMappings(mappings);
                    // TODO: validation of mappings?
                    // if (err) {
                    //   session.showMessage(err, {text_class: 'error'});
                    // } else {
                    //   session.showMessage('Loaded new hotkey settings!', {text_class: 'success'});
                    // }
                    session.clientStore.setClientSetting('hotkeys', hotkey_settings);
                  }}
                  onError={(error) => {
                    logger.error('Hotkeys file input error', error);
                    session.showMessage(`Error reading hotkeys: ${error}`, {text_class: 'error'});
                  }}
                  style={{float: 'left', position: 'relative'}}
                >
                  <div className='btn'
                    style={{
                      ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim'])
                    }}
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
                          clientStore={session.clientStore}
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
            clientStore={session.clientStore}
            pluginManager={this.props.pluginManager}
          />
        ),
      },
      {
        tab: TABS.ABOUT,
        heading: 'About',
        div: (
          <div>
            For more info, or to contact the maintainers, please visit
            {' '}
            <a href='https://github.com/WuTheFWasThat/vimflowy' style={{
              ...getStyles(session.clientStore, ['theme-link'])
            }}>
              the github website
            </a>.
          </div>
        ),
      },
    ];

    return (
      <div>
        {/* NOTE: must have theme as well so that inherit works for tabs*/}
        <ul className='tabs' style={{
          margin: 20,
          ...getStyles(session.clientStore, ['theme-bg-primary'])
        }}>
          {
            (() => {
              return _.map(tabs_info, (info) => {
                const isActive = info.tab === this.state.currentTab;
                return (
                  <li className={isActive ? 'active' : ''} key={info.tab}
                      style={{
                        ...getStyles(session.clientStore, ['theme-bg-secondary', 'theme-trim'])
                      }}
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
