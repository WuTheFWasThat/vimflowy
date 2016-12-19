import React from 'react';

import { PluginsManager, PluginStatus, names as PluginNames, getPlugin } from '../plugins';

type Props = {
  pluginManager: PluginsManager;
};
export default class PluginsTableComponent extends React.Component<Props, {}> {
  public render() {
    const pluginManager = this.props.pluginManager;
    return (
      <table style={{width: '100%', borderCollapse: 'collapse'}}>
        <thead>
          <tr>
            <th className='theme-trim'>
              Plugin
            </th>
            <th className='theme-trim'>
              Description
            </th>
            <th className='theme-trim' style={{maxWidth: '10%'}}>
              Version
            </th>
            <th className='theme-trim' style={{maxWidth: '15%'}}>
              Author
            </th>
            <th className='theme-trim' style={{maxWidth: '10%'}}>
              Status
            </th>
            <th className='theme-trim' style={{maxWidth: '20%'}}>
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
                    <div key={btnText} onClick={btnClick}
                      className='btn theme-trim' style={{width: 60}}>
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
                  <tr key={name} className='theme-bg-secondary'>
                    <td className='center theme-trim plugin-name'
                      style={tdStyle}
                    >
                      { name }
                    </td>
                    <td className='theme-trim'
                      style={Object.assign({fontSize: 12}, tdStyle)}
                    >
                      { plugin.description || '' }
                    </td>
                    <td className='center theme-trim'
                      style={tdStyle}
                    >
                      { (plugin.version || '') + '' }
                    </td>
                    <td className='center theme-trim'
                      style={Object.assign({fontSize: 12}, tdStyle)}
                    >
                      { plugin.author || '' }
                    </td>
                    <td className='center theme-trim'
                      style={Object.assign({boxShadow: `inset 0px 0px 0px 2px ${color}`}, tdStyle)}
                    >
                      {statusText}
                    </td>
                    <td className='center theme-trim'
                      style={tdStyle}
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
