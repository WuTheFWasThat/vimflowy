import React from 'react';

import logger from '../logger';

import LineComponent from './line';
import Spinner from './spinner.jsx';

export class RowComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      options: React.PropTypes.any.isRequired,
      path: React.PropTypes.any.isRequired,
      line: React.PropTypes.any.isRequired,
      pluginData: React.PropTypes.any,
      onLineMouseOver: React.PropTypes.func,
      onCharClick: React.PropTypes.func,
      onClick: React.PropTypes.func,
      style: React.PropTypes.any,
    };
  }

  constructor(props) {
    super(props);
  }

  render() {
    const session = this.props.session;
    const path = this.props.path;
    const options = this.props.options;
    const lineData = this.props.line;

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

    const hooksInfo = {
      path,
      pluginData: this.props.pluginData,
    };

    lineoptions.wordHook = (line, wordInfo) => {
      return session.applyHook('renderLineWordHook', line, {
        ...hooksInfo,
        wordInfo,
      });
    };

    lineoptions = session.applyHook('renderLineOptions', lineoptions, hooksInfo);
    let lineContents = [
      <LineComponent key='line'
        lineData={lineData}
        onCharClick={this.props.onCharClick && this.props.onCharClick.bind(this, path)}
        {...lineoptions}
      />
    ];
    lineContents = session.applyHook('renderLineContents', lineContents, hooksInfo);
    [].push.apply(results, lineContents);

    const infoChildren = session.applyHook('renderAfterLine', [], hooksInfo);

    return (
      <div key='text' className='node-text'
        onMouseOver={this.props.onLineMouseOver}
        onClick={this.props.onClick && this.props.onClick.bind(this, path)}
        style={this.props.style}
      >
        {results}
        {infoChildren}
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
      onLineMouseOver: React.PropTypes.func,
      onCharClick: React.PropTypes.func,
      onLineClick: React.PropTypes.func,
      onBulletClick: React.PropTypes.func,
      topLevel: React.PropTypes.bool,
      fetchData: React.PropTypes.func,
    };
  }

  render() {
    const session = this.props.session;
    const parent = this.props.path;
    const options = this.props.options;

    const pathElements = [];

    if (!parent.isRoot()) {
      const line = session.document.store.getLineSync(parent.row);
      if (line === null) {
        this.props.fetchData();
        return <Spinner/>;
      }

      const elLine = (
        <RowComponent key='row'
          style={{
            fontSize: this.props.topLevel ? 20 : null,
            marginBottom: this.props.topLevel ? 10 : null,
          }}
          session={session} path={parent} options={options}
          onLineMouseOver={this.props.onLineMouseOver}
          onCharClick={this.props.onCharClick}
          line={line}
          pluginData={{} /* TODO parentContents.plugins */}
          onClick={this.props.onLineClick}
        />
      );
      pathElements.push(elLine);
    }

    const children = session.document.store.getChildrenSync(parent.row);
    if (children === null) {
      this.props.fetchData();
      return <Spinner/>;
    }

    const collapsed = session.document.store.getCollapsedSync(parent.row);
    if (collapsed === null) {
      this.props.fetchData();
      return <Spinner/>;
    }

    if (children.length && ((!collapsed) || this.props.topLevel)) {
      pathElements.push(
        <div key='children' className='block'>
          {
            children.map((row) => {
              const path = parent.child(row);

              let cloneIcon = null;
              if (false /* TODO contents.isClone */) {
                cloneIcon = (
                  <i key='clone' className='fa fa-clone bullet clone-icon' title='Cloned'/>
                );
              }

              let onBulletClick = null;
              const style = {};

              let icon = 'fa-circle';

              const children = session.document.store.getChildrenSync(path.row);
              if (children === null) {
                this.props.fetchData();
                return <Spinner/>;
              }

              const collapsed = session.document.store.getCollapsedSync(path.row);
              if (collapsed === null) {
                this.props.fetchData();
                return <Spinner/>;
              }

              if (children.length) {
                icon = collapsed ? 'fa-plus-circle' : 'fa-minus-circle';
                if (this.props.onBulletClick) {
                  style.cursor = 'pointer';
                  onBulletClick = this.props.onBulletClick.bind(this, path);
                }
              }

              let bullet = (
                <i className={`fa ${icon} bullet`} key='bullet'
                  style={style} onClick={onBulletClick}
                  data-ancestry={JSON.stringify(path.getAncestry())}
                >
                </i>
              );
              bullet = session.applyHook('renderBullet', bullet, { path });

              return (
                <div key={path.row}>
                  {cloneIcon}
                  {bullet}
                  <BlockComponent key='block'
                   topLevel={false}
                   onLineMouseOver={this.props.onLineMouseOver}
                   onCharClick={this.props.onCharClick}
                   onLineClick={this.props.onLineClick}
                   onBulletClick={this.props.onBulletClick}
                   session={session} path={path} options={options}
                   fetchData={this.props.fetchData}
                 />
                </div>
              );
            })
          }
        </div>
      );
    }

    let className = 'node';
    if (parent.row in options.highlight_blocks) {
      className += ' theme-bg-highlight';
    }
    return (
      <div className={className}>
        {pathElements}
      </div>
    );
  }
}
