import React from 'react';

import logger from '../logger';

import LineComponent from './line';

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

    lineoptions.wordHook = session.applyHook.bind(session, 'renderLineWordHook');

    const hooksInfo = {
      path,
      pluginData: this.props.pluginData
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
      contents: React.PropTypes.any.isRequired,
      onLineMouseOver: React.PropTypes.func,
      onCharClick: React.PropTypes.func,
      onLineClick: React.PropTypes.func,
      onBulletClick: React.PropTypes.func,
      topLevel: React.PropTypes.bool,
    };
  }

  render() {
    const session = this.props.session;
    const parent = this.props.path;
    const options = this.props.options;
    const parentContents = this.props.contents;

    const pathElements = [];

    if (!parent.isRoot()) {
      const elLine = (
        <RowComponent key='row'
          style={{
            fontSize: this.props.topLevel ? 20 : null,
            marginBottom: this.props.topLevel ? 10 : null,
          }}
          session={session} path={parent} options={options}
          onLineMouseOver={this.props.onLineMouseOver}
          onCharClick={this.props.onCharClick}
          line={parentContents.line}
          pluginData={parentContents.plugins}
          onClick={this.props.onLineClick}
        />
      );
      pathElements.push(elLine);
    }

    if (parentContents.children) {
      pathElements.push(
        <div key='children' className='block'>
          {
            parentContents.children.map((contents) => {
              const path = contents.path;

              let cloneIcon = null;
              if (contents.isClone) {
                cloneIcon = (
                  <i key='clone' className='fa fa-clone bullet clone-icon' title='Cloned'/>
                );
              }

              let onBulletClick = null;
              const style = {};

              let icon = 'fa-circle';
              if (contents.hasChildren) {
                icon = contents.collapsed ? 'fa-plus-circle' : 'fa-minus-circle';
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
                   contents={contents}
                   topLevel={false}
                   onLineMouseOver={this.props.onLineMouseOver}
                   onCharClick={this.props.onCharClick}
                   onLineClick={this.props.onLineClick}
                   onBulletClick={this.props.onBulletClick}
                   session={session} path={path} options={options}/>
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
