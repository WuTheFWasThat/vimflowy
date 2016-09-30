import React from 'react';

import logger from '../logger';
import * as Modes from '../modes';

import LineComponent from './line';

const MODES = Modes.modes;

// TODO: move mode-specific logic into mode render functions

export class RowComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      options: React.PropTypes.any.isRequired,
      path: React.PropTypes.any.isRequired,
    };
  }

  constructor(props) {
    super(props);
  }

  render() {
    const session = this.props.session;
    const path = this.props.path;
    const options = this.props.options;

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
      <LineComponent key='line'
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

    return (
      <div key='text' className='node-text'
           onClick={() => {
             // if clicking outside of text, but on the row,
             // move cursor to the end of the row
             let col = options.cursorBetween ? -1 : -2;
             session.cursor.setPosition(path, col);
             options.rerender();
           }}
      >
        {session.applyHook('renderLineElements', results, { path })}
      </div>
    );
  }
}

export default class BlockComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      options: React.PropTypes.any.isRequired,
      path: React.PropTypes.any.isRequired,
    };
  }

  render() {
    const session = this.props.session;
    const path = this.props.path;
    const options = this.props.options;

    const pathElements = [];

    const style = {};
    let onClick = null;
    if (session.document.hasChildren(path.row)) {
      style.cursor = 'pointer';
      onClick = async () => {
        await session.toggleBlockCollapsed(path.row);
        session.save();
        options.rerender();
      };
    }

    if (!path.isRoot()) {
      const elLine = (
        <RowComponent key='row' session={session} path={path} options={options}/>
      );
      pathElements.push(elLine);
    }

    if (session.viewable(path)) {
      const children = session.document.getChildren(path);
      pathElements.push(
        <div key='children' className='block'>
          {
            children.map((child) => {

              let cloneIcon = null;
              if (session.document.isClone(child.row)) {
                cloneIcon = (
                  <i key='clone' className='fa fa-clone bullet clone-icon' title='Cloned'/>
                );
              }

              let icon = 'fa-circle';
              if (session.document.hasChildren(child.row)) {
                icon = session.document.collapsed(child.row) ? 'fa-plus-circle' : 'fa-minus-circle';
              }

              let bullet = (
                <i className={`fa ${icon} bullet`} key='bullet'
                  style={style} onClick={onClick}
                  data-ancestry={JSON.stringify(child.getAncestry())}
                >
                </i>
              );
              bullet = session.applyHook('renderBullet', bullet, { path: child });

              return (
                <div key={child.row}>
                  {cloneIcon}
                  {bullet}
                  <BlockComponent key='block'
                   session={session} path={child} options={options}/>
                </div>
              );
            })
          }
        </div>
      );
    }

    let className = 'node';
    if (path.row in options.highlight_blocks) {
      className += ' theme-bg-highlight';
    }
    return (
      <div className={className}>
        {pathElements}
      </div>
    );
  }
}
