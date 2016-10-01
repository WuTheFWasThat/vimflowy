import React from 'react';

import * as Modes from '../modes';

import BreadcrumbsComponent from './breadcrumbs';
import BlockComponent from './block';
import SpinnerComponent from './spinner';

const MODES = Modes.modes;

// TODO: move mode-specific logic into mode render functions

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
      handleCharClicks: false,
      viewContents: null,
    };
  }

  update() {
    this.updateFn && this.updateFn();
  }

  componentDidMount() {
    const session = this.props.session;
    this.updateFn = async () => {
      const viewContents = session.document.getViewContents(session.viewRoot.row);

      const highlight_blocks = {};
      if (session.lineSelect) {
        // mirrors logic of finishes_visual_line in keyHandler.js
        const [parent, index1, index2] = await session.getVisualLineSelections();
        session.document.getChildRange(parent, index1, index2).forEach((child) => {
          highlight_blocks[child.row] = true;
        });
      }

      const crumbContents = {};
      let path = session.viewRoot;
      while (!path.isRoot()) {
        path = path.parent;
        crumbContents[path.row] = session.document.getText(path.row).join('');
      }

      this.setState({
        handleCharClicks: false,
        highlight_blocks,
        viewContents,
        crumbContents,
      });
    };
    this.props.session.on('handledKey', this.updateFn);
    this.updateFn();
  }

  componentWillUnmount() {
    this.props.session.off('handledKey', this.updateFn);
  }

  // TODO: render without handleCharClicks when session changes?
  render() {
    const session = this.props.session;

    const viewContents = this.state.viewContents;
    if (viewContents === null) {
      return <div className='center'>
        <SpinnerComponent/>
      </div>;
    }

    const options = {
      cursorBetween: Modes.getMode(session.mode).metadata.hotkey_type === Modes.HotkeyType.INSERT_MODE_TYPE,
      handleCharClicks: this.state.handleCharClicks,
    };
    this.props.onRender(options);

    options.highlight_blocks = this.state.highlight_blocks || {};

    let onLineMouseOver = null;
    let onCharClick = null;
    let onLineClick = null;
    if (!this.state.handleCharClicks) {
      onLineMouseOver = () => this.setState({ handleCharClicks: true });
    }
    if (session.mode === MODES.NORMAL || session.mode === MODES.INSERT) {
      if (this.state.handleCharClicks) {
        onCharClick = (path, column, e) => {
          session.cursor.setPosition(path, column);
          // assume they might click again
          this.setState({handleCharClicks: true});
          // prevent overall path click
          e.stopPropagation();
          return false;
        };
      }
      onLineClick = (path) => {
        // if clicking outside of text, but on the row,
        // move cursor to the end of the row
        let col = options.cursorBetween ? -1 : -2;
        session.cursor.setPosition(path, col);
        this.update();
      };
    }

    const onBulletClick = async (path) => {
      await session.toggleBlockCollapsed(path.row);
      session.save();
      this.update();
    };

    let onCrumbClick = null;
    if (session.mode === MODES.NORMAL) {
      onCrumbClick = async (path) => {
        await session.zoomInto(path);
        session.save();
        this.update();
      };
    }

    // TODO: have an extra breadcrumb indicator when not at viewRoot?
    return (
      <div>
        {
          (() => {
            if (!session.viewRoot.isRoot()) {
              return [
                <BreadcrumbsComponent key='crumbs'
                  viewRoot={session.viewRoot}
                  onCrumbClick={onCrumbClick}
                  crumbContents={this.state.crumbContents}
                />,
                <hr key='bar' style={{opacity: 0.5, marginBottom: 20}}/>
              ];
            }
          })()
        }
        <BlockComponent
          session={session} path={session.viewRoot} options={options}
          topLevel={true}
          contents={viewContents}
          onCharClick={onCharClick}
          onLineClick={onLineClick}
          onLineMouseOver={onLineMouseOver}
          onBulletClick={onBulletClick}
        />
        {
          (() => {
            if (!viewContents.children.length) {
              let message = 'Nothing here yet.';
              if (session.mode === MODES.NORMAL) {
                message += ' Press o to start adding content!';
              }
              return (
                <div className='center'
                     style={{padding: 20, fontSize: 20, opacity: 0.5}}>
                  { message }
                </div>
              );
            }
          })()
        }
      </div>
    );
  }
}

