import React from 'react';

import { HotkeyMapping } from '../keyMappings';
import { KeyDefinitions, Motion, Action } from '../keyDefinitions';

type HotkeysTableProps = {
  keyMap: HotkeyMapping | null;
  definitions: KeyDefinitions;
  ignoreEmpty?: boolean;
};

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

      const el = (
        <tr key={name}>
          <td style={cellStyle}>
            { registration.name }
            <i className='fa fa-question-circle tooltip'
               title={registration.description} style={{float: 'right'}}/>
          </td>
          <td style={cellStyle}>
            {
              mappings_for_name.map((sequence, i) => {
                return (
                  <span key={i}>
                    {
                      (i > 0)
                      ? <span key='or'> OR </span>
                      : null
                    }
                    {
                      sequence.map((key, j) => {
                        return (
                          <span key={j}
                            className='theme-trim theme-bg-primary'
                            style={{
                              padding: 1,
                              borderRadius: 3,
                              margin: 1,
                            }}
                          >
                            {key}
                          </span>
                        );
                      })
                    }
                  </span>
                );
              })
            }

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
