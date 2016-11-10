import React from 'react';

import logger from '../logger';

import LineComponent, { LineProps } from './line';
import Spinner from './spinner';
import { Line } from '../types';

import Session from '../session';
import { CachedRowInfo } from '../document';
import Path from '../path';
import * as Modes from '../modes';
const MODES = Modes.modes;

type RowProps = {
  session: Session;
  options: any; // TODO
  path: Path;
  line: Line;
  pluginData: any;
  onLineMouseOver: (() => void) | undefined;
  onCharClick: ((path: Path, column: number, e: Event) => void) | null;
  onClick: ((path: Path) => void) | null;
  style: React.CSSProperties;
}
class RowComponent extends React.Component<RowProps, {}> {
  private onClick: (() => void) | undefined;
  private onCharClick: ((column: number, e: Event) => void) | null;

  // TODO: use shouldComponentUpdate?

  constructor(props) {
    super(props);
    this.init(props);
  }

  private init(props) {
    this.onClick = undefined;
    if (props.onClick) {
      this.onClick = () => props.onClick(props.path);
    }

    this.onCharClick = null;
    if (props.onCharClick) {
      this.onCharClick = (column: number, e: Event) => {
        props.onCharClick(props.path, column, e);
      };
    }
  }

  public componentWillReceiveProps(props) {
    this.init(props);
  }

  public render() {
    const session = this.props.session;
    const path = this.props.path;
    const options = this.props.options;
    const lineData = this.props.line;

    let cursors = {};
    const highlights = {};

    if (path.is(session.cursor.path)) {
      cursors[session.cursor.col] = true;

      if (session.anchor && (session.mode !== MODES.VISUAL_LINE)) {
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

    let lineoptions: LineProps = {
      lineData,
      cursors,
      highlights,
      cursorBetween: options.cursorBetween,
    };

    const hooksInfo = { path, pluginData: this.props.pluginData };

    lineoptions.wordHook = (line, wordInfo) => {
      return session.applyHook('renderLineWordHook', line, Object.assign({ wordInfo }, hooksInfo));
    };

    lineoptions = session.applyHook('renderLineOptions', lineoptions, hooksInfo);
    let lineContents = [
      <LineComponent key='line'
        onCharClick={this.onCharClick}
        {...lineoptions}
      />,
    ];
    lineContents = session.applyHook('renderLineContents', lineContents, hooksInfo);
    [].push.apply(results, lineContents);

    const infoChildren = session.applyHook('renderAfterLine', [], hooksInfo);

    return (
      <div key='text' className='node-text'
        onMouseOver={this.props.onLineMouseOver}
        onClick={this.onClick}
        style={this.props.style}
      >
        {results}
        {infoChildren}
      </div>
    );
  }
}

type BlockProps = {
  session: Session;
  options: any; // TODO
  path: Path;

  cached: CachedRowInfo | null;
  onLineMouseOver: (() => void) | undefined;
  onCharClick: ((path: Path, column: number, e: Event) => void) | null;
  onLineClick: ((path: Path) => void) | null;
  onBulletClick: ((path: Path) => void) | undefined;
  topLevel: boolean;
  fetchData: () => void;
}
export default class BlockComponent extends React.Component<BlockProps, {}> {
  private hasCursor: boolean;

  constructor(props) {
    super(props);
    this.hasCursor = props.session.cursor.path.isDescendant(props.path);
    // TODO: deal with visual mode
  }

  public shouldComponentUpdate(nextProps) {
    // TODO: hacky, move this stuff to cache itself?
    const hadCursor = this.hasCursor;
    this.hasCursor = nextProps.session.cursor.path.isDescendant(nextProps.path);
    if (nextProps.topLevel !== this.props.topLevel) {
      return true;
    }
    if (nextProps.cached !== this.props.cached) {
      return true;
    }
    if (!nextProps.path.is(this.props.path)) {
      return true;
    }
    if (hadCursor || this.hasCursor) {
      return true;
    }
    // TODO: options (contians cursorBetween, highlights, cursors)
    // TODO: other fns?

    return false;
  }

  public render() {
    const session = this.props.session;
    const parent = this.props.path;
    const options = this.props.options;
    const cached = this.props.cached;

    const pathElements: Array<React.ReactNode> = [];

    if (cached === null) {
      this.props.fetchData();
      return <Spinner/>;
    }

    if (!parent.isRoot()) {
      const elLine = (
        <RowComponent key='row'
          style={{
            fontSize: this.props.topLevel ? 20 : undefined,
            marginBottom: this.props.topLevel ? 10 : undefined,
          }}
          session={session} path={parent} options={options}
          onLineMouseOver={this.props.onLineMouseOver}
          onCharClick={this.props.onCharClick}
          line={cached.line}
          pluginData={cached.pluginData}
          onClick={this.props.onLineClick}
        />
      );
      pathElements.push(elLine);
    }

    const children = cached.childRows;
    const collapsed = cached.collapsed;

    if (this.props.topLevel && !children.length) {
      let message = 'Nothing here yet.';
      if (session.mode === MODES.NORMAL) {
        // TODO move this
        message += ' Press `o` to start adding content!';
      }
      pathElements.push(
        <div key='nothing' className='center'
             style={{padding: 20, fontSize: 20, opacity: 0.5}}>
          { message }
        </div>
      );
    } else if (children.length && ((!collapsed) || this.props.topLevel)) {
      let childrenLoaded = true;
      let childrenDivs = cached.children.map((cachedChild) => {
        if (cachedChild === null) {
          childrenLoaded = false;
          return null;
        }

        const row = cachedChild.row;
        const path = parent.child(row);

        let cloneIcon: React.ReactNode | null = null;

        const parents = cachedChild.parentRows;
        // NOTE: this is not actually correct!
        // should use isClone, which is different since a parent may be detached
        if (parents.length > 1) {
          cloneIcon = (
            <i key='clone' className='fa fa-clone bullet clone-icon' title='Cloned'/>
          );
        }

        const style: React.CSSProperties = {};

        let icon = 'fa-circle';

        let onBulletClick: (() => void) | undefined = undefined;
        if (cachedChild.childRows.length) {
          icon = cachedChild.collapsed ? 'fa-plus-circle' : 'fa-minus-circle';
          const onBulletClickProp = this.props.onBulletClick;
          if (onBulletClickProp != null) {
            onBulletClick = () => onBulletClickProp(path);
            style.cursor = 'pointer';
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
             cached={cachedChild}
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
      });

      if (!childrenLoaded) {
        this.props.fetchData();
        childrenDivs = [<Spinner key='spinner'/>];
      }

      pathElements.push(
        <div key='children' className='block'>
          {childrenDivs}
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
