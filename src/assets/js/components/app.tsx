import React from 'react';

import * as Modes from '../modes';
import * as errors from '../errors';

import SettingsComponent from './settings';
import SessionComponent, { RenderOptions } from './session';
import MenuComponent from './menu';
import { ModeHotkeysTableComponent } from './hotkeysTable';
import { PluginsManager } from '../plugins';
import Session from '../session';
import KeyBindings from '../keyBindings';

type Props = {
  pluginManager: PluginsManager;
  session: Session;
  showingKeyBindings: boolean;
  keyBindings: KeyBindings;
  initialTheme: string;
  initialDataSource: string;
  onThemeChange: (theme: string) => void;
  onRender: (opts: RenderOptions) => void;
  onExport: () => void;
  error: Error | null;
}
export default class AppComponent extends React.Component<Props, {}> {
  public render() {
    if (this.props.error !== null) {
      const wasExpected = this.props.error instanceof errors.ExpectedError;
      const unexpectedMessage = (
        <div style={{marginBottom: 20}}>
          Please help out Vimflowy and report the bug!
          Simply open the javascript console, save the log as debug information,
          and send it to the Vimflowy dev team with a brief description of what happened.
        </div>
      );
      return (
        <div style={{padding: 50}}>
          <div style={{marginBottom: 20}}>
            An error was caught.  Please refresh the page to avoid weird state.
          </div>
          { wasExpected ? null : unexpectedMessage }
          <div style={{marginBottom: 20}}>
            ERROR:
          </div>
          <div>
            {this.props.error.message}
            { wasExpected ? null :
              <div style={{marginTop: 20}}>
                {JSON.stringify(this.props.error.stack)}
              </div>
            }
          </div>
        </div>
      );
    }
    const pluginManager = this.props.pluginManager;
    const session = this.props.session;
    const keyBindings = this.props.keyBindings;
    const settingsMode = session.mode === Modes.modes.SETTINGS;
    return (
      <div>
        {/* hack for firefox paste */}
        <div id='paste-hack' contentEditable={true} className='offscreen'>
        </div>

        <div id='contents'>
          <div id='menu'
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

          <div id='view'
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
              <ModeHotkeysTableComponent
                keyBindings={keyBindings}
                mode={session.mode}
              />
            </div>
          </div>

          <div id='settings' className={'theme-bg-primary ' + (settingsMode ? '' : 'hidden')}>
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

          <div id='bottom-bar' className='theme-bg-primary theme-trim'
            style={{ display: 'flex' }}
          >
            <a className='center theme-bg-secondary'
              onClick={async () => {
                if (settingsMode) {
                  await session.setMode(Modes.modes.NORMAL);
                } else {
                  await session.setMode(Modes.modes.SETTINGS);
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
              style={{flexBasis: 0, flexGrow: 1}}
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
