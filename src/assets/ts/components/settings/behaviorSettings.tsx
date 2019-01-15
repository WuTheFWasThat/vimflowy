import * as React from 'react';

import { ClientStore } from '../../datastore';

type Props = {
  clientStore: ClientStore;
};

type State = {
  copyToClipboard: boolean;
  formattedCopy: boolean;
};

export default class BehaviorSettingsComponent extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);

    const clientStore = props.clientStore;
    this.state = {
      copyToClipboard: clientStore.getClientSetting('copyToClipboard'),
      formattedCopy: clientStore.getClientSetting('formattedCopy'),
    };
    this.setCopyToClipboard = this.setCopyToClipboard.bind(this);
    this.setFormattedCopy = this.setFormattedCopy.bind(this);
  }

  private setCopyToClipboard(copyToClipboard: boolean): boolean {
    this.setState({ copyToClipboard: copyToClipboard });
    this.props.clientStore.setClientSetting('copyToClipboard', copyToClipboard);
    return this.state.copyToClipboard;
  }

  private setFormattedCopy(formattedCopy: boolean): boolean {
    this.setState({ formattedCopy: formattedCopy });
    this.props.clientStore.setClientSetting('formattedCopy', formattedCopy);
    return this.state.formattedCopy;
  }

  public render() {
    return (
      <div style={{ fontSize: '1.3em' }}>
        <SettingsCheckbox id={'copyToClipboard'}
          fn={this.setCopyToClipboard}
          checked={this.state.copyToClipboard}
          name='Copy to system clipboard'
          desc='copy yanked text to system clipboard'
        />
        <SettingsCheckbox id={'formattedCopy'}
          fn={this.setFormattedCopy}
          checked={this.state.formattedCopy}
          name='Formatted block copy'
          desc='format with indents and hyphens when copying bullets with children to system clipboard'
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

class SettingsCheckbox extends React.Component<SettingsCheckboxProps, {}> {
  constructor(props: SettingsCheckboxProps) {
    super(props);
  }

  public render() {
    return (
      <div style={{ fontSize: '0.9em', marginBottom: '0.3em' }}>
        <input type='checkbox' id={this.props.id} checked={this.props.checked} onChange={(e) => {
          this.props.fn(e.target.checked);
        }} />
        <label htmlFor={this.props.id} style={{ marginLeft: '0.5rem' }}>
          {this.props.name + ' - '}
          <span style={{ fontSize: '0.9em' }}>{this.props.desc}</span>
        </label>
      </div>
    );
  }
}
