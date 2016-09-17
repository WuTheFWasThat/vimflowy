import React from 'react';

import logger from '../logger';
import * as Modes from '../modes';

import LineComponent from './line.jsx';

const MODES = Modes.modes;

// TODO: move mode-specific logic into mode render functions

function virtualRenderLine(session, path, options = {}) {
  const lineData = session.document.getLine(path.row);
  let cursors = {};
  const highlights = {};

  if (path.is(session.cursor.path)) {
    cursors[session.cursor.col] = true;

    if (session.anchor && !session.lineSelect) {
      if (session.anchor.path && path.is(session.anchor.path)) {
        const start = Math.min(session.cursor.col, session.anchor.col);
        const end = Math.max(session.cursor.col, session.anchor.col);
        for (let j = start; j <= end; j++) {
          highlights[j] = true;
        }
      } else {
        logger.warn('Multiline not yet implemented');
      }
    }
  }

  const results = [];

  let lineoptions = {
    cursors,
    highlights,
    cursorBetween: options.cursorBetween
  };

  if (options.handle_clicks) {
    if (session.mode === MODES.NORMAL || session.mode === MODES.INSERT) {
      lineoptions.charclick = function(column, e) {
        session.cursor.setPosition(path, column);
        // assume they might click again
        options.rerender({handle_clicks: true});
        // prevent overall path click
        e.stopPropagation();
        return false;
      };
    }
  } else {
    lineoptions.linemouseover = () => options.rerender({handle_clicks: true});
  }

  lineoptions.wordHook = session.applyHook.bind(session, 'renderLineWordHook');

  lineoptions = session.applyHook('renderLineOptions', lineoptions, { path });
  let lineContents = [
    <LineComponent
      lineData={lineData}
      {...lineoptions}
    />
  ];
  lineContents = session.applyHook('renderLineContents', lineContents, { path });
  [].push.apply(results, lineContents);

  const infoChildren = session.applyHook('renderInfoElements', [], { path });

  const info = (
    <span key='info' className='node-info'>
      {infoChildren}
    </span>
  );
  results.push(info);

  return session.applyHook('renderLineElements', results, { path });
}

function virtualRenderTree(session, parent, options = {}) {
  if ((!options.ignoreCollapse) && session.document.collapsed(parent.row)) {
    return;
  }

  return session.document.getChildren(parent).map((path) => {
    const pathElements = [];

    if (session.document.isClone(path.row)) {
      const cloneIcon = (
        <i className='fa fa-clone bullet clone-icon' title='Cloned'/>
      );
      pathElements.push(cloneIcon);
    }

    let icon = 'fa-circle';
    if (session.document.hasChildren(path.row)) {
      icon = session.document.collapsed(path.row) ? 'fa-plus-circle' : 'fa-minus-circle';
    }

    const style = {};
    let onClick = null;
    if (session.document.hasChildren(path.row)) {
      style.cursor = 'pointer';
      onClick = () => {
        session.toggleBlockCollapsed(path.row);
        session.save();
        options.rerender();
      };
    }

    let bullet = (
      <i className={`fa ${icon} bullet`} key='bullet'
        style={style} onClick={onClick}
        data-ancestry={JSON.stringify(path.getAncestry())}
      >
      </i>
    );
    bullet = session.applyHook('renderBullet', bullet, { path });

    pathElements.push(bullet);

    const elLine = (
      <div key={'text_' + path.row} className='node-text'
           onClick={() => {
             // if clicking outside of text, but on the row,
             // move cursor to the end of the row
             let col = options.cursorBetween ? -1 : -2;
             session.cursor.setPosition(path, col);
             options.rerender();
           }}
      >
        {virtualRenderLine(session, path, options)}
      </div>
    );
    pathElements.push(elLine);

    options.ignoreCollapse = false;
    const children = (
      <div className='node-children' key='children'>
        {virtualRenderTree(session, path, options)}
      </div>
    );
    pathElements.push(children);

    let className = 'node';
    if (path.row in options.highlight_blocks) {
      className += ' theme-bg-highlight';
    }

    const postHookPathElements = session.applyHook('renderPathElements', pathElements, { path });

    return (
      <div className={className} key={path.row}>
        {postHookPathElements}
      </div>
    );
  });
}

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
      cursorBetween: Modes.getMode(session.mode).metadata.hotkey_type === Modes.HotkeyType.INSERT_MODE_TYPE,
      rerender: (options = {}) => {
        this.setState({
          t: Date.now(),
          handleClicks: options.handle_clicks,
        });
      },
      handle_clicks: this.state.handleClicks,
    };
    this.props.onRender(options);

    const crumbs = [];
    let path = session.viewRoot;
    while (!path.is(session.document.root)) {
      crumbs.push(path);
      path = path.parent;
    }

    const makeCrumb = (path, isLast) => {
      let className = '';
      let onClick = null;
      if (session.mode === MODES.NORMAL && !isLast) {
        className = 'theme-text-link';
        onClick = async () => {
          await session.zoomInto(path);
          session.save();
          options.rerender();
        };
      }
      return (
        <span key={'crumb_' + path.row} className='crumb'>
          <span className={className} onClick={onClick}>
            {
              (() => {
                if (isLast) {
                  return virtualRenderLine(session, path, options);
                } else if (path.is(session.document.root)) {
                  return <icon className='fa fa-home'/>;
                } else {
                  return session.document.getText(path.row).join('');
                }
              })()
            }
          </span>
        </span>
      );
    };

    const crumbNodes = [];
    crumbNodes.push(makeCrumb(session.document.root));
    for (let i = crumbs.length - 1; i >= 0; i--) {
      path = crumbs[i];
      crumbNodes.push(makeCrumb(path, i===0));
    }

    const breadcrumbsNode = (
      <div key='breadcrumbs' className='breadcrumbs'
        style={{
          fontSize: 20,
          marginBottom: 20,
        }}
      >
        {crumbNodes}
      </div>
    );

    options.ignoreCollapse = true; // since we're the root, even if we're collapsed, we should render

    options.highlight_blocks = {};
    if (session.lineSelect) {
      // mirrors logic of finishes_visual_line in keyHandler.js
      const [parent, index1, index2] = session.getVisualLineSelections();
      session.document.getChildRange(parent, index1, index2).forEach((child) => {
        options.highlight_blocks[child.row] = true;
      });
    }

    let contentsNode;
    if (session.document.hasChildren(session.viewRoot.row)) {
      contentsNode = (
        <div key='contents'>
          {virtualRenderTree(session, session.viewRoot, options)}
        </div>
      );
    } else {
      let message = 'Nothing here yet.';
      if (session.mode === MODES.NORMAL) {
        message += ' Press o to start adding content!';
      }
      contentsNode = (
        <div key='contents' className='center'
             style={{padding: 20, fontSize: 20, opacity: 0.5}}>
          { message }
        </div>
      );
    }

    return (
      <div>
        {breadcrumbsNode}
        {contentsNode}
      </div>
    );
  }
}

