import React from 'react';

import * as Modes from '../modes';

import BreadcrumbsComponent from './breadcrumbs';
import BlockComponent from './block';

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
    };
  }

  rerender(options = {}) {
    this.setState({
      t: Date.now(),
      handleCharClicks: options.handleCharClicks,
    });
  }

  // TODO: render without handleCharClicks when session changes?
  render() {
    const session = this.props.session;

    const options = {
      cursorBetween: Modes.getMode(session.mode).metadata.hotkey_type === Modes.HotkeyType.INSERT_MODE_TYPE,
      handleCharClicks: this.state.handleCharClicks,
    };
    this.props.onRender(options);

    options.highlight_blocks = {};
    if (session.lineSelect) {
      // mirrors logic of finishes_visual_line in keyHandler.js
      const [parent, index1, index2] = session.getVisualLineSelections();
      session.document.getChildRange(parent, index1, index2).forEach((child) => {
        options.highlight_blocks[child.row] = true;
      });
    }

    const viewContents = session.document.getViewContents(session.viewRoot.row);
    let onLineMouseOver = null;
    let onCharClick = null;
    let onLineClick = null;
    if (!this.state.handleCharClicks) {
      onLineMouseOver = () => this.rerender({handleCharClicks: true});
    }
    if (session.mode === MODES.NORMAL || session.mode === MODES.INSERT) {
      if (this.state.handleCharClicks) {
        onCharClick = (path, column, e) => {
          session.cursor.setPosition(path, column);
          // assume they might click again
          this.rerender({handleCharClicks: true});
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
        this.rerender();
      };
    }

    const onBulletClick = async (path) => {
      await session.toggleBlockCollapsed(path.row);
      session.save();
      this.rerender();
    };

    let onCrumbClick = null;
    if (session.mode === MODES.NORMAL) {
      onCrumbClick = async (path) => {
        await session.zoomInto(path);
        session.save();
        this.rerender();
      };
    }

    // TODO: have an extra breadcrumb indicator when not at viewRoot?
    return (
      <div>
        <BreadcrumbsComponent session={session} onCrumbClick={onCrumbClick}/>
        <BlockComponent
          session={session} path={session.viewRoot} options={options}
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
                <div key='message' className='center'
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

