import React from 'react';

import { HotkeyMapping } from '../keyMappings';
import { KeyDefinitions, Motion, Action } from '../keyDefinitions';

type HotkeysTableProps = {
  keyMap: HotkeyMapping | null;
  definitions: KeyDefinitions;
  ignoreEmpty?: boolean;
}

export default class HotkeysTableComponent extends React.Component<HotkeysTableProps, {}> {
  public render() {
    const keyMap = this.props.keyMap;
    if (!keyMap) {
      return <div>No hotkeys!</div>;
    }
    const definitions = this.props.definitions;
    const ignoreEmpty = this.props.ignoreEmpty;

    const actionRows: Array<React.ReactNode> = [];
    const motionRows: Array<React.ReactNode> = [];

    Object.keys(keyMap).forEach((name) => {
      const registration = definitions.getRegistration(name);
      if (registration === null) { return; }
      const mappings_for_name = keyMap[name];
      if (mappings_for_name.length === 0 && ignoreEmpty) {
        return;
      }

      const cellStyle = { fontSize: 10, border: '1px solid', padding: 5 };

      /*
          <div className='tooltip' title={MODE_TYPES[mode_type].description}>
          </div>
      */

      const el = (
        <tr key={name}>
          <td key='keys' style={cellStyle}>
            { mappings_for_name.join(' OR ') }
          </td>
          <td key='desc' style={ Object.assign({width: '100%'}, cellStyle) }>
            { registration.description }
          </td>
        </tr>
      );

      if (registration instanceof Motion) {
        motionRows.push(el);
      } else if (registration instanceof Action) {
        actionRows.push(el);
      } else {
        throw new Error(
          `Unexpected: unknown registration type for ${registration}`
        );
      }

    });

    return (
      <div>
        {
          (() => {
            return [
              {label: 'Motions', rows: motionRows},
              {label: 'Actions', rows: actionRows},
            ].map(({label, rows}) => {
              return [
                <h5 key={label + '_header'} style={{margin: '5px 10px'}}>
                  {label}
                </h5>
                ,
                <table key={label + '_table'} className='theme-bg-secondary'
                       style={{width: '100%'}}
                >
                  <tbody>
                    {rows}
                  </tbody>
                </table>,
              ];
            });
          })()
        }
      </div>
    );
  }
}
