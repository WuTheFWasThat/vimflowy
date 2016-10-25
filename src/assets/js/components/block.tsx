import React from 'react';

import logger from '../logger';

import LineComponent, { LineProps } from './line';
import Spinner from './spinner';
import { Line } from '../types';

import Session from '../session';
import Path from '../path';
import * as Modes from '../modes';
const MODES = Modes.modes;

type RowProps = {
  session: Session;
  options: any; // TODO
  path: Path;
  line: Line;
  onLineMouseOver: (() => void) | undefined;
  onCharClick: ((path: Path, column: number, e: Event) => void) | null;
  onClick: ((path: Path) => void) | null;
  style: React.CSSProperties;
}
export class RowComponent extends React.Component<RowProps, {}> {
  constructor(props) {
    super(props);
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

    const pluginData = session.document.applyHook('pluginPathContentsSync', {}, { path });
    const hooksInfo = { path, pluginData };

    lineoptions.wordHook = (line, wordInfo) => {
      return session.applyHook('renderLineWordHook', line, Object.assign({ wordInfo }, hooksInfo));
    };

    lineoptions = session.applyHook('renderLineOptions', lineoptions, hooksInfo);
    let lineContents = [
      <LineComponent key='line'
        onCharClick={this.props.onCharClick && this.props.onCharClick.bind(this, path)}
        {...lineoptions}
      />,
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

type BlockProps = {
  session: Session;
  options: any; // TODO
  path: Path;

  onLineMouseOver: (() => void) | undefined;
  onCharClick: ((path: Path, column: number, e: Event) => void) | null;
  onLineClick: ((path: Path) => void) | null;
  onBulletClick: ((path: Path) => void) | undefined;
  topLevel: boolean;
  fetchData: () => void;
}
export default class BlockComponent extends React.Component<BlockProps, {}> {
  public render() {
    const session = this.props.session;
    const parent = this.props.path;
    const options = this.props.options;

    const pathElements: Array<React.ReactNode> = [];

    if (!parent.isRoot()) {
      const line = session.document.store.getLineSync(parent.row);
      if (line === null) {
        this.props.fetchData();
        return <Spinner/>;
      }

      const elLine = (
        <RowComponent key='row'
          style={{
            fontSize: this.props.topLevel ? 20 : undefined,
            marginBottom: this.props.topLevel ? 10 : undefined,
          }}
          session={session} path={parent} options={options}
          onLineMouseOver={this.props.onLineMouseOver}
          onCharClick={this.props.onCharClick}
          line={line}
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
      let childrenDivs = children.map((row) => {
        const path = parent.child(row);

        let cloneIcon: React.ReactNode | null = null;

        const parents = session.document.store.getParentsSync(path.row);
        if (parents === null) {
          childrenLoaded = false;
          return null;
        }
        // NOTE: this is not actually correct!
        // should use isClone, which is different since a parent may be detached
        if (parents.length > 1) {
          cloneIcon = (
            <i key='clone' className='fa fa-clone bullet clone-icon' title='Cloned'/>
          );
        }

        let onBulletClick = undefined;
        const style: React.CSSProperties = {};

        let icon = 'fa-circle';

        const child_children = session.document.store.getChildrenSync(path.row);
        if (child_children === null) {
          childrenLoaded = false;
          return null;
        }

        const child_collapsed = session.document.store.getCollapsedSync(path.row);
        if (child_collapsed === null) {
          childrenLoaded = false;
          return null;
        }

        if (child_children.length) {
          icon = child_collapsed ? 'fa-plus-circle' : 'fa-minus-circle';
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
