import React from 'react';

export default class Spinner extends React.Component {
  static get propTypes() {
    return {
      fontSize: React.PropTypes.number
      // loadingText: React.PropTypes.string
    };
  }

  render() {
    return (
      <i className='fa fa-spin fa-spinner'
        style={{fontSize: this.props.fontSize || 20}}
      />
    );
  }
}

