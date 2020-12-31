import * as React from 'react';

import { PluginsManager, PluginStatus, names as PluginNames, getPlugin } from '../plugins';
import { getStyles } from '../themes';
import { ClientStore } from '../datastore';

type Props = {
  clientStore: ClientStore;
  pluginManager: PluginsManager;
};
export default class PluginsTableComponent extends React.Component<Props, {}> {
  public render() {
    const pluginManager = this.props.pluginManager;
    return (
      <table style={{width: '100%', borderCollapse: 'collapse'}}>
        <thead>
          <tr>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
            }}>
              Plugin
            </th>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
            }}>
              Description
            </th>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
            }}>
              Dependencies
            </th>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
              maxWidth: '10%',
            }}>
              Version
            </th>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
              maxWidth: '15%',
            }}>
              Author
            </th>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
              maxWidth: '10%',
            }}>
              Status
            </th>
            <th style={{
              ...getStyles(this.props.clientStore, ['theme-trim']),
              maxWidth: '20%',
            }}>
              Actions
            </th>
          </tr>
        </thead>
        <tbody>
          {
            PluginNames().map(
              name => {
                const status = pluginManager.getStatus(name);
                const actions: Array<React.ReactNode> = [];
                let btnClick;
                let btnText;
                if (status === PluginStatus.ENABLED) {
                  btnClick = async () => {
                    return await pluginManager.disable(name);
                  };
                  btnText = 'Disable';
                } else if (status === PluginStatus.DISABLED) {
                  btnClick = async () => {
                    return await pluginManager.enable(name);
                  };
                  btnText = 'Enable';
                }
                if (btnText) {
                  actions.push(
                    <div key={btnText} onClick={btnClick} className='btn'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        width: 60
                      }}
                    >
                      {btnText}
                    </div>
                  );
                }

                let color = 'inherit';
                if (status === PluginStatus.ENABLED) {
                  color = 'green';
                } else if (status === PluginStatus.ENABLING ||
                           status === PluginStatus.DISABLING) {
                  color = 'yellow';
                } else if (status === PluginStatus.UNREGISTERED ||
                           status === PluginStatus.DISABLED) {
                  color = 'red';
                }

                let statusText;
                if (status === PluginStatus.ENABLED) {
                  statusText = 'Enabled';
                } else if (status === PluginStatus.ENABLING) {
                  statusText = 'Enabling';
                } else if (status === PluginStatus.DISABLED) {
                  statusText = 'Disabled';
                } else if (status === PluginStatus.DISABLING) {
                  statusText = 'Disabling';
                } else if (status === PluginStatus.UNREGISTERED) {
                  statusText = 'Unregistered';
                }

                const plugin = getPlugin(name) || {};
                const tdStyle = { padding: 5};
                return (
                  <tr key={name}
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-bg-secondary'])
                      }}
                  >
                    <td className='center plugin-name'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle,
                      }}
                    >
                      { name }
                    </td>
                    <td
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle,
                        fontSize: 12
                      }}
                    >
                      { plugin.description || '' }
                    </td>
                    <td className='center'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle
                      }}
                    >
                      { (plugin.dependencies || []).join(', ') }
                    </td>
                    <td className='center'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle
                      }}
                    >
                      { (plugin.version || '') + '' }
                    </td>
                    <td className='center'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle,
                        fontSize: 12
                      }}
                    >
                      { plugin.author || '' }
                    </td>
                    <td className='center'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle,
                       boxShadow: `inset 0px 0px 0px 2px ${color}`
                      }}
                    >
                      {statusText}
                    </td>
                    <td className='center'
                      style={{
                        ...getStyles(this.props.clientStore, ['theme-trim']),
                        ...tdStyle,
                      }}
                    >
                      {actions}
                    </td>
                  </tr>
                );
              }
            )
          }
        </tbody>
      </table>
    );
  }
}
