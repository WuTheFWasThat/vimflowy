import * as React from 'react';
import $ from 'jquery';

type Props = {
  onSelect?: (filename: string) => void;
  onLoad?: (filename: string, contents: string) => void;
  onError?: (error: string) => void;
  style?: React.CSSProperties;
};

export const load_file = function(file: File): Promise<{name: string, contents: string}> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsText(file, 'UTF-8');
    reader.onload = function(evt) {
      const content = (evt.target as any).result;
      return resolve({
        name: file.name,
        contents: content,
      });
    };
    reader.onerror = function(err) {
      reject(`Failed to reading file: ${err}`);
    };
  });
};

export default class FileInput extends React.Component<Props, {}> {
  private id: string;

  constructor(props: Props) {
    super(props);
    this.id = `fileinput.${Math.random()}`;
  }

  private handleChange(e: React.FormEvent<HTMLInputElement>) {
    // TODO: what is the right type here?
    const file = (e.target as any).files[0];
    if (!file) { return; } // do nothing, they canceled

    if (this.props.onSelect) {
      this.props.onSelect(file.name);
    }
    load_file(file).then(({ name, contents }) => {
      if (this.props.onLoad) {
        this.props.onLoad(name, contents);
      }
      $(`#${this.id}`).val('');
    }).catch((err: string) => {
      if (this.props.onError) {
        this.props.onError(err);
      }
      $(`#${this.id}`).val('');
    });
  }

  public render() {
    return (
      <div
        style={this.props.style || {position: 'relative'}}
      >
        <input type='file' id={this.id}
          style={{
            position: 'absolute',
            opacity: 0,
            width: '100%', height: '100%',
            zIndex: 1,
            cursor: 'pointer',
          }}
          onChange={(e) => this.handleChange(e)}
        />

        {this.props.children}
      </div>
    );
  }
}
