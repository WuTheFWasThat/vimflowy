import * as React from 'react';

import { ClientStore } from '../../datastore';

type Props = {
  clientStore: ClientStore;
};
type State = {
  copyToClipboard: boolean;
};
export default class BehaviorSettingsComponent extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);

    const clientStore = props.clientStore;
    this.state = {
      copyToClipboard: clientStore.getClientSetting('copyToClipboard'),
    };
    this.setCopyToClipboard = this.setCopyToClipboard.bind(this);
  }

  private setCopyToClipboard(copyToClipboard: boolean): boolean {
    this.setState({ copyToClipboard: copyToClipboard });
    this.props.clientStore.setClientSetting('copyToClipboard', copyToClipboard);
    console.log("set copytoclipboard: " + this.props.clientStore.getClientSetting('copyToClipboard'));
    return this.state.copyToClipboard;
  }

  public render() {
    return (
      <div style={{ fontSize: "1.3em" }}>
        <div style={{ marginBottom: 10 }}>
          These settings modify various aspects of the default Vimflowy behavior.
        </div>
        <SettingsCheckbox id={"copyToClipboard"}
          fn={this.setCopyToClipboard}
          checked={this.state.copyToClipboard}
          name="Copy to system clipboard"
          desc="copy yanked text to system clipboard"
        />
      </div>
    );
  }
}

interface SettingsCheckboxProps {
  id: string;
  name: string;
  desc: string;
  fn: (val: boolean) => void;
  checked: boolean;
}

class SettingsCheckbox extends React.Component<SettingsCheckboxProps, {}>{
  constructor(props: SettingsCheckboxProps) {
    super(props);
  }

  public render() {
    return (
      <div style={{ fontSize: "0.9em" }}>
        <input type="checkbox" id={this.props.id} checked={this.props.checked} onChange={(e) => {
          this.props.fn(e.target.checked);
        }} />
        <label htmlFor={this.props.id} style={{ marginLeft: "0.5rem" }}>
          {this.props.name + " - "}
          <span style={{ fontSize: "0.9em" }}>{this.props.desc}</span>
        </label>
      </div>
    );
  }
}