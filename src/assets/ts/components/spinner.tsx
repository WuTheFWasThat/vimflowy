import * as React from 'react';

type Props = {
  fontSize?: number;
  loadingText?: string;
};
export default class Spinner extends React.PureComponent<Props, {}> {
  public render() {
    const style = {
      fontSize: this.props.fontSize || 20,
      marginRight: this.props.loadingText ? 10 : 0,
    };

    return (
      <span>
        <i className='fa fa-spin fa-spinner'
          style={style}
        />
        {this.props.loadingText}
      </span>
    );
  }
}

