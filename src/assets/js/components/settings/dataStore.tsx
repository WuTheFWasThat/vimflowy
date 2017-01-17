import React from 'react';

import { DataSource } from '../../datastore';
import Settings from '../../settings';

type Props = {
  settings: Settings;
  initialDataSource: DataSource;
};
type State = {
  dataSource: DataSource,
  firebaseId: string,
  firebaseApiKey: string,
  firebaseUserEmail: string,
  firebaseUserPassword: string,
};
export default class DataStoreSettingsComponent extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = {
      dataSource: props.initialDataSource,
      firebaseId: '',
      firebaseApiKey: '',
      firebaseUserEmail: '',
      firebaseUserPassword: '',
    };
  }

  public componentDidMount() {
    (async () => {
      const settings = this.props.settings;
      const firebaseId = await settings.getDocSetting('firebaseId');
      const firebaseApiKey = await settings.getDocSetting('firebaseApiKey');
      const firebaseUserEmail = await settings.getDocSetting('firebaseUserEmail');
      const firebaseUserPassword = await settings.getDocSetting('firebaseUserPassword');
      this.setState({
        firebaseId,
        firebaseApiKey,
        firebaseUserEmail,
        firebaseUserPassword,
      } as State);
    })();
  }

  private async saveDataSettings() {
    const settings = this.props.settings;
    const dataSource = this.state.dataSource;
    await settings.setDocSetting('dataSource', dataSource);
    if (dataSource === 'firebase') {
      const firebaseId = this.state.firebaseId;
      const firebaseApiKey = this.state.firebaseApiKey;
      const firebaseUserEmail = this.state.firebaseUserEmail;
      const firebaseUserPassword = this.state.firebaseUserPassword;
      await settings.setDocSetting('firebaseId', firebaseId);
      await settings.setDocSetting('firebaseApiKey', firebaseApiKey);
      await settings.setDocSetting('firebaseUserEmail', firebaseUserEmail);
      await settings.setDocSetting('firebaseUserPassword', firebaseUserPassword);
    }
    window.location.reload();
  }

  private setDataSource(dataSource: DataSource) {
    this.setState({
      dataSource,
    } as State);
  }

  private setFirebaseId(firebaseId: string) {
    this.setState({
      firebaseId,
    } as State);
  }

  private setFirebaseApiKey(firebaseApiKey: string) {
    this.setState({
      firebaseApiKey,
    } as State);
  }

  private setFirebaseUserEmail(firebaseUserEmail: string) {
    this.setState({
      firebaseUserEmail,
    } as State);
  }

  private setFirebaseUserPassword(firebaseUserPassword: string) {
    this.setState({
      firebaseUserPassword,
    } as State);
  }

  public render() {
    const firebaseBaseUrl = `https://console.firebase.google.com/project/${this.state.firebaseId || '${firebaseProjectId}'}`;

    const dataSources: Array<{
      name: string,
      type: 'Remote' | 'Local',
      value: DataSource,
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
            For details on configuration, <a href={'https://github.com/WuTheFWasThat/vimflowy/tree/master/docs/storage/Firebase.md'}>
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
              dataSources.forEach((dataSourceInfo) => {
                const selected = this.state.dataSource === dataSourceInfo.value;
                rows.push(
                  <tr key={dataSourceInfo.value}>
                    <td style={{padding: 10}}>
                      <input type='radio' name='dataSource'
                        value={dataSourceInfo.value} checked={selected} readOnly
                        onClick={(ev) => this.setDataSource((ev.target as HTMLInputElement).value as DataSource)}
                      />
                    </td>
                    <td style={{padding: 10}}>
                      <b>{dataSourceInfo.name}</b>
                    </td>
                    <td style={{padding: 10}}>
                      {dataSourceInfo.type}
                    </td>
                    <td style={{padding: 10}}>
                      {dataSourceInfo.info}
                    </td>
                  </tr>
                );

                if (selected && dataSourceInfo.config) {
                  rows.push(
                    <tr key='selected'>
                      <td></td>
                      <td colSpan={999}>
                        {dataSourceInfo.config}
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
