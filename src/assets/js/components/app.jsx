import React from 'react';

import * as Modes from '../modes';

import SettingsComponent from './settings.jsx';
import SessionComponent from './session.jsx';
import MenuComponent from './menu.jsx';
import { ModeHotkeysTableComponent } from './hotkeysTable.jsx';

export default class AppComponent extends React.Component {
  static get propTypes() {
    return {
      pluginManager: React.PropTypes.any.isRequired,
      session: React.PropTypes.any.isRequired,
      showingKeyBindings: React.PropTypes.bool.isRequired,
      keyBindings: React.PropTypes.any.isRequired,
      initialTheme: React.PropTypes.string.isRequired,
      initialDataSource: React.PropTypes.string.isRequired,
      onThemeChange: React.PropTypes.func.isRequired,
      onRender: React.PropTypes.func.isRequired,
      onExport: React.PropTypes.func.isRequired,
    };
  }

  render() {
    const pluginManager = this.props.pluginManager;
    const session = this.props.session;
    const keyBindings = this.props.keyBindings;
    const settingsMode = session.mode === Modes.modes.SETTINGS;
    return (
      <div>
        {/* hack for firefox paste */}
        <div id="paste-hack" contentEditable="true" className="offscreen">
        </div>

        <div id="contents">
          <div id="menu"
            className={session.mode === Modes.modes.SEARCH ? '' : 'hidden'}
          >
            {
              (() => {
                if (session.menu) {
                  return <MenuComponent menu={session.menu} session={session}/>;
                }
              })()
            }
          </div>

          <div id="view"
            style={{flex: '1 1 auto', fontSize: 10}}
            className={session.mode === Modes.modes.SEARCH ? 'hidden' : ''}
          >
            {/* NOTE: maybe always showing session would be nice?
              * Mostly works to never have 'hidden',
              * but would be cool if it mirrored selected search result
              */}
              <SessionComponent
                session={session}
                onRender={this.props.onRender}
              />
            </div>

            <div
              className={'theme-bg-secondary transition-ease-width'}
              style={
                (() => {
                  const style = {
                    overflowY: 'auto',
                    height: '100%',
                    flex: '0 1 auto',
                    position: 'relative',
                  };
                  if (this.props.showingKeyBindings) {
                    style.width = 500;
                  } else {
                    style.width = '0%';
                  }
                  return style;
                })()
              }
            >
              <ModeHotkeysTableComponent
                keyBindings={keyBindings}
                mode={session.mode}
              />
            </div>
          </div>

          <div id="settings" className={'theme-bg-primary ' + (settingsMode ? '' : 'hidden')}>
            <SettingsComponent
              session={session}
              keyBindings={keyBindings}
              pluginManager={pluginManager}
              initialTheme={this.props.initialTheme}
              initialDataSource={this.props.initialDataSource}
              onThemeChange={(theme) => {
                this.props.onThemeChange(theme);
              }}
              onExport={this.props.onExport}
            />
          </div>

          <div id="bottom-bar" className="theme-bg-primary theme-trim"
            style={{ display: 'flex' }}
          >
            <a className="center theme-bg-secondary"
              onClick={async () => {
                if (settingsMode) {
                  await session.setMode(Modes.modes.NORMAL);
                } else {
                  await session.setMode(Modes.modes.SETTINGS);
                }
              }}
              style={{
                flexBasis: 100, flexGrow: 0,
                cursor: 'pointer', textDecoration: 'none'
              }}
            >
              <div className={settingsMode ? 'hidden' : ''}>
                <span style={{marginRight:10}} className="fa fa-cog">
                </span>
                <span>Settings
                </span>
              </div>
              <div className={settingsMode ? '' : 'hidden'}>
                <span style={{marginRight:10}} className="fa fa-arrow-left">
                </span>
                <span>
                  Back
                </span>
              </div>
            </a>
            <div id="message"
              style={{flexBasis: 0, flexGrow: 1}}
            >
            </div>
            {/* should be wide enough to fit the words 'VISUAL LINE'*/}
            <div className="center theme-bg-secondary"
              style={{flexBasis: 80, flexGrow: 0}}
            >
              {Modes.getMode(session.mode).name}
            </div>
          </div>

          <a id="export" className="hidden"> </a>
        </div>
    );
  }
}
