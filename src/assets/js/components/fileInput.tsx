import React from 'react';
import $ from 'jquery';

type Props = {
  onSelect?: (filename: string) => void;
  onLoad?: (filename: string, contents: string) => void;
  onError?: (error: string) => void;
  style?: React.CSSProperties;
};

export const load_file = function(file) {
  return new Promise((resolve, reject) => {
    if (!file) {
      return reject('No file selected for import!');
    }
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

  constructor(props) {
    super(props);
    this.id = `fileinput.${Math.random()}`;
  }

  private handleChange(e) {
    const file = e.target.files[0];
    if (this.props.onSelect) {
      this.props.onSelect(file.name);
    }
    load_file(file).then(({ name, contents }) => {
      if (this.props.onLoad) {
        this.props.onLoad(name, contents);
      }
      $(`#${this.id}`).val('');
    }).catch((err) => {
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
};

