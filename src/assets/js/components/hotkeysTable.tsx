import React from 'react';

import KeyBindings, { KeyMapping } from '../keyBindings';
import { Motions, ActionsForMode } from '../keyDefinitions';
import { ModeId } from '../types';

type HotkeysTableProps = {
  keyMap: KeyMapping;
  motions: Motions;
  actions: ActionsForMode;
  ignoreEmpty?: boolean;
}

export default class HotkeysTableComponent extends React.Component<HotkeysTableProps, {}> {
  public render() {
    const keyMap = this.props.keyMap;
    const motions = this.props.motions;
    const actions = this.props.actions;
    const ignoreEmpty = this.props.ignoreEmpty;

    const buildTableContents = function(bindings, recursed = false) {
      const result = [];
      for (const k in bindings) {
        const v = bindings[k];
        let keys;
        if (k === 'MOTION') {
          if (recursed) {
            keys = ['<MOTION>'];
          } else {
            continue;
          }
        } else {
          keys = keyMap[k];
          if (!keys) {
            continue;
          }
        }

        if (keys.length === 0 && ignoreEmpty) {
          continue;
        }

        const cellStyle = { fontSize: 10, border: '1px solid', padding: 5 };

        const el = (
          <tr key={k}>
            <td key='keys' style={cellStyle}>
              { keys.join(' OR ') }
            </td>
            <td key='desc' style={ Object.assign({width: '100%'}, cellStyle) }>
              { v.description }
              {
                (() => {
                  if (typeof v.definition === 'object') {
                    return buildTableContents(v.definition, true);
                  }
                })()
              }
            </td>
          </tr>
        );

        result.push(el);
      }
      return result;
    };

    return (
      <div>
        {
          (() => {
            return [
              {label: 'Motions', definitions: motions},
              {label: 'Actions', definitions: actions},
            ].map(({label, definitions}) => {
              return [
                <h5 key={label + '_header'} style={{margin: '5px 10px'}}>
                  {label}
                </h5>
                ,
                <table key={label + '_table'} className='theme-bg-secondary'
                       style={{width: '100%'}}
                >
                  <tbody>
                    {buildTableContents(definitions)}
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

type ModeHotkeysTableProps = {
  keyBindings: KeyBindings;
  mode: ModeId;
}
export class ModeHotkeysTableComponent extends React.Component<ModeHotkeysTableProps, {}> {
  public render() {
    const keyBindings = this.props.keyBindings;
    const mode = this.props.mode;
    return <HotkeysTableComponent
      keyMap={keyBindings.keyMaps[mode]}
      motions={keyBindings.definitions.motions}
      actions={keyBindings.definitions.actions_for_mode(mode)}
    />;
  }
}

