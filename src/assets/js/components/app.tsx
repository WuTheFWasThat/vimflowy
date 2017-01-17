import React from 'react';

import * as Modes from '../modes';
import * as errors from '../errors';
import { DataSource } from '../datastore';
import Settings from '../settings';

import SettingsComponent from './settings';
import SessionComponent from './session';
import MenuComponent from './menu';
import HotkeysTableComponent from './hotkeysTable';
import { PluginsManager } from '../plugins';
import Session from '../session';
import Config from '../config';
import KeyBindings from '../keyBindings';

type Props = {
  pluginManager: PluginsManager;
  session: Session;
  settings: Settings;
  config: Config;
  showingKeyBindings: boolean;
  keyBindings: KeyBindings;
  initialTheme: string;
  initialDataSource: DataSource;
  onThemeChange: (theme: string) => void;
  onExport: () => void;
  error: Error | null;
};
export default class AppComponent extends React.Component<Props, {}> {
  public render() {
    if (this.props.error !== null) {
      const wasExpected = this.props.error instanceof errors.ExpectedError;

      let message;
      if (wasExpected) {
        message = (
          <div>
            {this.props.error.message}
          </div>
        );
      } else {
        message = (
          <div>
            An unexpected error was caught!
            <br/>
            <br/>
            Please help out Vimflowy and report the bug.
            Report the issue {' '}
            <a href='https://github.com/WuTheFWasThat/vimflowy/issues/new'>
              here
            </a>
            {' '} with:
            <ul>
              <li>
                a description of what you did
              </li>
              <li>
                a copy of the Javascript console output (ideally, but be careful if data privacy is important)
              </li>
              <li>
                a copy of the following error message
              </li>
            </ul>
            <h3>
              Error:
            </h3>
            <pre style={{marginLeft: 20}}>
              {this.props.error.message}
              <br/>
              <br/>
              {this.props.error.stack}
            </pre>
            <br/>
            Refresh the page to continue.
          </div>
        );
      }

      return (
        <div style={{padding: 50}}>
          {message}
        </div>
      );
    }
    const pluginManager = this.props.pluginManager;
    const session = this.props.session;
    const keyBindings = this.props.keyBindings;
    const settingsMode = session.mode === 'SETTINGS';
    return (
      <div>
        {/* hack for firefox paste */}
        <div id='paste-hack' contentEditable={true} className='offscreen'>
        </div>

        <div id='contents'>
          <div id='menu'
            className={session.mode === 'SEARCH' ? '' : 'hidden'}
          >
            {
              (() => {
                if (session.menu) {
                  return <MenuComponent menu={session.menu} session={session}/>;
                }
              })()
            }
          </div>

          <div id='view'
            style={{flex: '1 1 auto', fontSize: 10}}
            className={session.mode === 'SEARCH' ? 'hidden' : ''}
          >
            {/* NOTE: maybe always showing session would be nice?
              * Mostly works to never have 'hidden',
              * but would be cool if it mirrored selected search result
              */}
              <SessionComponent
                session={session}
              />
            </div>

            <div
              className={'theme-bg-secondary transition-ease-width'}
              style={
                (() => {
                  const style: React.CSSProperties = {
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
              <HotkeysTableComponent
                keyMap={keyBindings.mappings.mappings[session.mode]}
                definitions={keyBindings.definitions}
                ignoreEmpty={true}
              />
            </div>
          </div>

          <div id='settings' className={'theme-bg-primary ' + (settingsMode ? '' : 'hidden')}>
            <SettingsComponent
              session={this.props.session}
              settings={this.props.settings}
              config={this.props.config}
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

          <div id='bottom-bar' className='theme-bg-primary theme-trim'
            style={{ display: 'flex' }}
          >
            <a className='center theme-bg-secondary'
              onClick={async () => {
                if (settingsMode) {
                  await session.setMode('NORMAL');
                } else {
                  await session.setMode('SETTINGS');
                }
              }}
              style={{
                flexBasis: 100, flexGrow: 0,
                cursor: 'pointer', textDecoration: 'none',
              }}
            >
              <div className={settingsMode ? 'hidden' : ''}>
                <span style={{marginRight:10}} className='fa fa-cog'>
                </span>
                <span>Settings
                </span>
              </div>
              <div className={settingsMode ? '' : 'hidden'}>
                <span style={{marginRight:10}} className='fa fa-arrow-left'>
                </span>
                <span>
                  Back
                </span>
              </div>
            </a>
            <div id='message'
              style={{flexBasis: 0, flexGrow: 1, overflowX: 'scroll'}}
            >
            </div>
            <div id='status'
              style={{flexBasis: 0, flexGrow: 0}}
            >
            </div>
            {/* should be wide enough to fit the words 'VISUAL LINE'*/}
            <div className='center theme-bg-secondary'
              style={{flexBasis: 80, flexGrow: 0}}
            >
              {Modes.getMode(session.mode).name}
            </div>
          </div>

          <a id='export' className='hidden'> </a>
        </div>
    );
  }
}
