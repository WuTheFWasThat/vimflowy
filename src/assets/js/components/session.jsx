import React from 'react';

import * as Modes from '../modes';

import BreadcrumbsComponent from './breadcrumbs';
import BlockComponent from './block';
import Spinner from './spinner.jsx';

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
      loaded: false,
      t: Date.now(),
    };

    const session = this.props.session;

    function promiseDebounce(fn) {
      let running = false;
      let pending = false;
      const run = () => {
        running = true;
        fn.apply(fn, arguments).then(() => {
          if (pending) {
            pending = false;
            run();
          } else {
            running = false;
          }
        });
      };
      return () => {
        if (!running) {
          run();
        } else {
          pending = true;
        }
      };
    }

    this.updateFn = promiseDebounce(async () => {
      const t = Date.now();

      const highlight_blocks = {};
      if (session.lineSelect) {
        // mirrors logic of finishes_visual_line in keyHandler.js
        const [parent, index1, index2] = await session.getVisualLineSelections();
        const children = await session.document.getChildRange(parent, index1, index2);
        children.forEach((child) => {
          highlight_blocks[child.row] = true;
        });
      }

      const crumbContents = {};
      let path = session.viewRoot;
      while (!path.isRoot()) {
        path = path.parent;
        crumbContents[path.row] = await session.document.getText(path.row);
      }

      this.setState({
        handleCharClicks: false,
        highlight_blocks,
        crumbContents,
        mode: session.mode,
        viewRoot: session.viewRoot,
        t: Date.now(), // to force rerendering
        loaded: true,
      });
      console.log('Took time', Date.now() - t); // eslint-disable-line no-console
    });
  }

  async fetchAndRerender() {
    const session = this.props.session;
    // await (new Promise((resolve) => {
    //   setTimeout(resolve, 2000);
    // }));
    await session.document.getViewContents(session.viewRoot, true);
    this.update();
  }

  update() {
    this.updateFn && this.updateFn();
  }

  componentWillReceiveProps() {
    this.update();
  }

  componentDidMount() {
    this.props.session.on('handledKey', this.updateFn);
    this.update();
  }

  componentWillUnmount() {
    this.props.session.off('handledKey', this.updateFn);
  }

  render() {
    const session = this.props.session;
    if (!this.state.loaded) { return <Spinner/>; }
    const mode = this.state.mode;

    const viewRoot = this.state.viewRoot;

    const options = {
      cursorBetween: Modes.getMode(mode).metadata.hotkey_type === Modes.HotkeyType.INSERT_MODE_TYPE,
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
    if (mode === MODES.NORMAL || mode === MODES.INSERT) {
      if (this.state.handleCharClicks) {
        onCharClick = (path, column, e) => {
          // NOTE: this is fire and forget
          session.cursor.setPosition(path, column).then(() => {
            // assume they might click again
            this.setState({handleCharClicks: true});
          });

          // prevent overall path click
          e.stopPropagation();
          return false;
        };
      }
      onLineClick = async (path) => {
        // if clicking outside of text, but on the row,
        // move cursor to the end of the row
        let col = options.cursorBetween ? -1 : -2;
        await session.cursor.setPosition(path, col);
        this.update();
      };
    }

    const onBulletClick = async (path) => {
      await session.toggleBlockCollapsed(path.row);
      session.save();
      this.update();
    };

    let onCrumbClick = null;
    if (mode === MODES.NORMAL) {
      onCrumbClick = async (path) => {
        await session.zoomInto(path);
        session.save();
        this.update();
      };
    }

    const children = session.document.store.getChildrenSync(viewRoot.row);
    if (children === null) {
      this.fetchAndRerender();
      return <Spinner/>;
    }

    // TODO: have an extra breadcrumb indicator when not at viewRoot?
    return (
      <div>
        {
          (() => {
            if (!viewRoot.isRoot()) {
              return [
                <BreadcrumbsComponent key='crumbs'
                  viewRoot={viewRoot}
                  onCrumbClick={onCrumbClick}
                  crumbContents={this.state.crumbContents}
                />,
                <hr key='bar' style={{opacity: 0.5, marginBottom: 20}}/>
              ];
            }
          })()
        }
        <BlockComponent
          session={session} path={viewRoot} options={options}
          topLevel={true}
          onCharClick={onCharClick}
          onLineClick={onLineClick}
          onLineMouseOver={onLineMouseOver}
          onBulletClick={onBulletClick}
          fetchData={() => this.fetchAndRerender()}
        />
      </div>
    );
  }
}

