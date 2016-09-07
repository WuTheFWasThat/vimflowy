import React from 'react';

import { virtualRenderSession } from '../render.jsx';
import * as Modes from '../modes';

// TODO: add way to profile render time
export default class SessionComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      onRender: React.PropTypes.func.isRequired,
    };
  }

  constructor(props) {
    super(props);
    this.state = {
      handleClicks: false,
    };
  }

  render() {
    const session = this.props.session;
    const options = {
      cursorBetween: Modes.getMode(session.mode).metadata.hotkey_type === Modes.INSERT_MODE_TYPE,
      rerender: (options = {}) => {
        this.setState({
          t: Date.now(),
          handleClicks: options.handle_clicks,
        });
      },
      handle_clicks: this.state.handleClicks,
    };
    this.props.onRender(options);
    return virtualRenderSession(session, options);
  }
}

