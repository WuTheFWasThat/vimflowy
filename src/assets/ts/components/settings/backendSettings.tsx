import * as React from 'react';

import { BackendType } from '../../data_backend';
import { ClientStore } from '../../datastore';

type Props = {
  clientStore: ClientStore;
  initialBackendType: BackendType;
};
type State = {
  backendType: BackendType,
  firebaseId: string,
  firebaseApiKey: string,
  firebaseUserEmail: string,
  firebaseUserPassword: string,
  socketServerHost: string,
  socketServerPassword: string,
  socketServerDocument: string,
};
export default class BackendSettingsComponent extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = {
      backendType: props.initialBackendType,
      firebaseId: '',
      firebaseApiKey: '',
      firebaseUserEmail: '',
      firebaseUserPassword: '',
      socketServerHost: '',
      socketServerPassword: '',
      socketServerDocument: '',
    };
  }

  public componentDidMount() {
    (async () => {
      const clientStore = this.props.clientStore;
      const [
        firebaseId, firebaseApiKey, firebaseUserEmail, firebaseUserPassword,
        socketServerHost, socketServerPassword, socketServerDocument,
      ] = await Promise.all([
        clientStore.getDocSetting('firebaseId'),
        clientStore.getDocSetting('firebaseApiKey'),
        clientStore.getDocSetting('firebaseUserEmail'),
        clientStore.getDocSetting('firebaseUserPassword'),
        clientStore.getDocSetting('socketServerHost'),
        clientStore.getDocSetting('socketServerPassword'),
        clientStore.getDocSetting('socketServerDocument'),
      ]);
      this.setState({
        firebaseId,
        firebaseApiKey,
        firebaseUserEmail,
        firebaseUserPassword,
        socketServerHost,
        socketServerPassword,
        socketServerDocument,
      } as State);
    })();
  }

  private async saveDataSettings() {
    const clientStore = this.props.clientStore;
    const backendType = this.state.backendType;
    await clientStore.setDocSetting('dataSource', backendType);
    if (backendType === 'firebase') {
      const firebaseId = this.state.firebaseId;
      const firebaseApiKey = this.state.firebaseApiKey;
      const firebaseUserEmail = this.state.firebaseUserEmail;
      const firebaseUserPassword = this.state.firebaseUserPassword;
      await Promise.all([
        clientStore.setDocSetting('firebaseId', firebaseId),
        clientStore.setDocSetting('firebaseApiKey', firebaseApiKey),
        clientStore.setDocSetting('firebaseUserEmail', firebaseUserEmail),
        clientStore.setDocSetting('firebaseUserPassword', firebaseUserPassword),
      ]);
    } else if (backendType === 'socketserver') {
      const socketServerHost = this.state.socketServerHost;
      const socketServerPassword = this.state.socketServerPassword;
      const socketServerDocument = this.state.socketServerDocument;
      await Promise.all([
        clientStore.setDocSetting('socketServerHost', socketServerHost),
        clientStore.setDocSetting('socketServerPassword', socketServerPassword),
        clientStore.setDocSetting('socketServerDocument', socketServerDocument),
      ]);
    }
    window.location.reload();
  }

  private setBackendType(backendType: BackendType) {
    this.setState({ backendType } as State);
  }

  private setFirebaseId(firebaseId: string) {
    this.setState({ firebaseId } as State);
  }

  private setFirebaseApiKey(firebaseApiKey: string) {
    this.setState({ firebaseApiKey } as State);
  }

  private setFirebaseUserEmail(firebaseUserEmail: string) {
    this.setState({ firebaseUserEmail } as State);
  }

  private setFirebaseUserPassword(firebaseUserPassword: string) {
    this.setState({ firebaseUserPassword } as State);
  }

  private setSocketServerHost(socketServerHost: string) {
    this.setState({ socketServerHost } as State);
  }

  private setSocketServerPassword(socketServerPassword: string) {
    this.setState({ socketServerPassword } as State);
  }

  private setSocketServerDocument(socketServerDocument: string) {
    this.setState({ socketServerDocument } as State);
  }

  public render() {
    const firebaseBaseUrl = `https://console.firebase.google.com/project/${this.state.firebaseId || '${firebaseProjectId}'}`;

    const backendTypes: Array<{
      name: string,
      type: 'Remote' | 'Local',
      value: BackendType,
      info: React.ReactElement<any> | string,
      config?: React.ReactElement<any>,
    }> = [
      {
        name: 'HTML5 Local Storage (default)',
        type: 'Local',
        value: 'local',
        info: `
          Stores data on your computer, through standard browser APIs.
          No backups, so you should export regularly.
          Clearing local storage will result in data loss.
        `,
      },
      {
        name: 'In-memory',
        type: 'Local',
        value: 'inmemory',
        info: `
          Not saved at all!
          Data loss as soon as you close the tab.
          Good for testing with complete throw-away data.
        `,
      },
      {
        name: 'Firebase',
        type: 'Remote',
        value: 'firebase',
        info: (
          <div>
            Stores data in Google's Firebase cloud service.
            Regular backups can be turned on.
            {' '}
            <a href={'https://github.com/WuTheFWasThat/vimflowy/tree/master/docs/storage/Firebase.md'}>
              Details here
            </a>.
          </div>
        ),
        config: (
          <div>
            For details on configuration, <a href={'https://github.com/WuTheFWasThat/vimflowy/tree/master/docs/storage/firebase.md'}>
              see here
            </a>.
            <br/>
            <table><tbody>
              <tr>
                <td>
                  Firebase ID
                </td>
                <td>
                  <input type='text'
                    value={this.state.firebaseId}
                    placeholder='e.g. something-fiery-2222'
                    onChange={(ev) => this.setFirebaseId((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
              <tr>
                <td>
                  Firebase API Key
                  (found {' '}
                  <a href={`${firebaseBaseUrl}/settings/general/`}>
                    here
                  </a>
                  )
                </td>
                <td>
                  <input type='text'
                    value={this.state.firebaseApiKey}
                    placeholder='should be a long string of alphanumeric digits and dashes'
                    onChange={(ev) => this.setFirebaseApiKey((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
              <tr>
                <td>
                  Firebase User Email
                  (added {' '}
                  <a href={`${firebaseBaseUrl}/authentication/users`}>
                    here
                  </a>
                  )
                </td>
                <td>
                  <input type='text'
                    value={this.state.firebaseUserEmail}
                    onChange={(ev) => this.setFirebaseUserEmail((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
              <tr>
                <td>
                  Firebase User Password
                </td>
                <td>
                  <input type='password'
                    value={this.state.firebaseUserPassword}
                    onChange={(ev) => this.setFirebaseUserPassword((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
            </tbody></table>
            <br/>
          </div>
        ),
      },
      {
        name: 'Vimflowy server',
        type: 'Remote',
        value: 'socketserver',
        info: `
          Client talks to a server over websockets.
          Server stores data in SQLite.
        `,
        config: (
          <div>
            For details on configuration, <a href={'https://github.com/WuTheFWasThat/vimflowy/tree/master/docs/storage/socket_server.md'}>
              see here
            </a>.
            <br/>
            <table><tbody>
              <tr>
                <td>
                  Server
                </td>
                <td>
                  <input type='text'
                    value={this.state.socketServerHost}
                    placeholder='e.g. ws://localhost:3000 or wss://54.0.0.1:3000'
                    onChange={(ev) => this.setSocketServerHost((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
              <tr>
                <td>
                  Password
                </td>
                <td>
                  <input type='password'
                    value={this.state.socketServerPassword}
                    onChange={(ev) => this.setSocketServerPassword((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
              <tr>
                <td>
                  Document
                </td>
                <td>
                  <input type='text'
                    value={this.state.socketServerDocument}
                    onChange={(ev) => this.setSocketServerDocument((ev.target as HTMLInputElement).value)}
                    style={{float: 'right'}}
                  />
                </td>
              </tr>
            </tbody></table>
            <br/>
          </div>
        ),
      },
    ];

    return (
      <div>
        <div style={{marginBottom: 10}}>
          <b> Local </b> data sources:
          <ul>
            <li>
              Offline access supported
            </li>
            <li>
              Data is never sent over the internet
            </li>
            <li>
              Can only be accessed from this browser
            </li>
          </ul>
        </div>
        <div style={{marginBottom: 10}}>
          <b> Remote </b> data sources:
          <ul>
            <li>
              Can be accessed from multiple devices or browsers
            </li>
            <li>
              No offline support
            </li>
          </ul>
        </div>

        <table style={{width: '100%', borderCollapse: 'collapse'}}>
          <thead>
            <tr>
              <th></th>
              <th className='theme-trim' style={{padding: 10}}>
                Storage Type
              </th>
              <th className='theme-trim' style={{padding: 10}}>
                Local/Remote
              </th>
              <th className='theme-trim' style={{padding: 10}}>
                Info
              </th>
            </tr>
          </thead>
          <tbody>
            { (() => {
              const rows: Array<React.ReactElement<any>> = [];
              backendTypes.forEach((backendTypeInfo) => {
                const selected = this.state.backendType === backendTypeInfo.value;
                rows.push(
                  <tr key={backendTypeInfo.value}>
                    <td style={{padding: 10}}>
                      <input type='radio' name='backendType'
                        value={backendTypeInfo.value} checked={selected} readOnly
                        onClick={(ev) => this.setBackendType((ev.target as HTMLInputElement).value as BackendType)}
                      />
                    </td>
                    <td style={{padding: 10}}>
                      <b>{backendTypeInfo.name}</b>
                    </td>
                    <td style={{padding: 10}}>
                      {backendTypeInfo.type}
                    </td>
                    <td style={{padding: 10}}>
                      {backendTypeInfo.info}
                    </td>
                  </tr>
                );

                if (selected && backendTypeInfo.config) {
                  rows.push(
                    <tr key='selected'>
                      <td></td>
                      <td colSpan={999}>
                        {backendTypeInfo.config}
                      </td>
                    </tr>
                  );
                }
              });
              return rows;
            })() }
          </tbody>
        </table>

        <div className='btn theme-bg-secondary theme-trim'
          onClick={() => this.saveDataSettings()} >
          Load Data Settings
        </div>
        <h5 style={{display: 'inline-block'}}>
        (WARNING: will reload page)
        </h5>
      </div>
    );
  }
}
