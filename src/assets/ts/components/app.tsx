import * as React from 'react';

import * as browser_utils from '../utils/browser';
import * as errors from '../../../shared/utils/errors';
import * as Modes from '../modes';
import { BackendType } from '../data_backend';
import { PluginsManager } from '../plugins';
import Session from '../session';
import Config from '../config';
import KeyBindings from '../keyBindings';
import { getStyles } from '../themes';

import SettingsComponent from './settings';
import SessionComponent from './session';
import MenuComponent from './menu';
import HotkeysTableComponent from './hotkeysTable';

export type TextMessage = { message?: string, text_class?: string };

type Props = {
  pluginManager: PluginsManager;
  session: Session;
  config: Config;
  message: TextMessage | null;
  saveMessage: TextMessage | null;
  showingKeyBindings: boolean;
  keyBindings: KeyBindings;
  initialBackendType: BackendType;
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
    const userMessage: TextMessage = this.props.message || {};
    const saveMessage: TextMessage = this.props.saveMessage || {};

    return (
      <div style={{
          ...getStyles(session.clientStore, ['theme-text-primary'])
      }}>
        {/* hack for firefox paste */}
        <div id='paste-hack' contentEditable={true} className='offscreen'>
        </div>

        <div id='contents' style={{
          ...getStyles(session.clientStore, ['theme-bg-primary'])
        }}>
          <div id='menu'
            className={session.mode === 'SEARCH' ? '' : 'hidden'}
          >
            {
              (() => {
                if (session.menu) {
                  return <MenuComponent menu={session.menu} session={session}/>;
                }
                return null;
              })()
            }
          </div>

          <div id='view'
            style={{
              flex: '1 1 auto', fontSize: 10,
              ...getStyles(session.clientStore, ['theme-bg-primary'])
            }}
            className={session.mode === 'SEARCH' ? ' hidden' : ''}
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
              className='transition-ease-width'
              style={{
                overflowY: 'auto',
                height: '100%',
                flex: '0 1 auto',
                position: 'relative',
                width: this.props.showingKeyBindings ? 500 : '0%',
                ...getStyles(session.clientStore, ['theme-bg-secondary'])
              }}
            >
              <HotkeysTableComponent
                clientStore={session.clientStore}
                keyMap={keyBindings.mappings.mappings[session.mode]}
                definitions={keyBindings.definitions}
                ignoreEmpty={true}
              />
            </div>
          </div>

          <div id='settings' className={settingsMode ? '' : 'hidden'}
            style={{
              ...getStyles(session.clientStore, ['theme-bg-primary'])
            }}>

            <SettingsComponent
              session={session}
              config={this.props.config}
              keyBindings={keyBindings}
              pluginManager={pluginManager}
              initialBackendType={this.props.initialBackendType}
              rerenderAll={() => {
                // TODO: this doesn't actually update everything.. use a better way to do this?
                // See: https://github.com/facebook/react/issues/3038
                // Maybe could do session.document.cache.clear(), but that's inefficient
                this.forceUpdate();
              }}
              onExport={() => {
                const filename = 'vimflowy_hotkeys.json';
                const content = JSON.stringify(keyBindings.mappings.serialize(), null, 2);
                browser_utils.downloadFile(filename, content, 'application/json');
                session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
              }}
            />
          </div>

          <div id='bottom-bar'
            style={{
              display: 'flex',
              ...getStyles(session.clientStore, ['theme-bg-primary', 'theme-trim'])
            }}>
            <a className='center'
              onClick={async () => {
                await session.setMode(settingsMode ? 'NORMAL' : 'SETTINGS');
              }}
              style={{
                flexBasis: 100, flexGrow: 0,
                cursor: 'pointer', textDecoration: 'none',
                ...getStyles(session.clientStore, ['theme-bg-secondary'])
              }}
            >
              <div>
                <span style={{marginRight: 10}}
                  className={`fa ${settingsMode ? 'fa-arrow-left' : 'fa-cog'}`}>
                </span>
                <span>{settingsMode ? 'Back' : 'Settings'}</span>
              </div>
            </a>
            <div style={{flexBasis: 0, flexGrow: 1, overflowX: 'hidden'}}
              className={userMessage.text_class}>
              {userMessage.message}
            </div>
            <div style={{flexBasis: 0, flexGrow: 0}}
              className={saveMessage.text_class}>
              {saveMessage.message}
            </div>
            {/* should be wide enough to fit the words 'VISUAL LINE'*/}
            <div className='center'
              style={{
                flexBasis: 80, flexGrow: 0,
                ...getStyles(session.clientStore, ['theme-bg-secondary'])
              }}
            >
              {Modes.getMode(session.mode).name}
            </div>
          </div>
        </div>
    );
  }
}
