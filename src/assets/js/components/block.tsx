import React from 'react';

import LineComponent, { LineProps } from './line';
import Spinner from './spinner';

import Session from '../session';
import { CachedRowInfo } from '../document';
import Path from '../path';
import { CursorsInfoTree } from '../cursor';

type RowProps = {
  session: Session;
  path: Path;
  cached: CachedRowInfo;
  onCharClick: ((path: Path, column: number, e: Event) => void) | null;
  onClick: ((path: Path) => void) | null;
  style: React.CSSProperties;
  cursorsTree: CursorsInfoTree;
  cursorBetween: boolean;
}
class RowComponent extends React.Component<RowProps, {}> {
  private onClick: (() => void) | undefined;
  private onCharClick: ((column: number, e: Event) => void) | null;

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
    const lineData = this.props.cached.line;
    const cursorsTree = this.props.cursorsTree;

    const cursors = {};
    const highlights = {};

    if (cursorsTree.cursor != null) {
      cursors[cursorsTree.cursor] = true;
    }
    Object.keys(cursorsTree.selected).forEach((col) => {
      highlights[col] = true;
    });
    const results = [];

    let lineoptions: LineProps = {
      lineData,
      cursors,
      highlights,
      cursorBetween: this.props.cursorBetween,
    };

    const hooksInfo = { path, pluginData: this.props.cached.pluginData };

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
  path: Path;

  cached: CachedRowInfo | null;
  cursorsTree: CursorsInfoTree;
  cursorBetween: boolean;
  onCharClick: ((path: Path, column: number, e: Event) => void) | null;
  onLineClick: ((path: Path) => void) | null;
  onBulletClick: ((path: Path) => void) | undefined;
  topLevel: boolean;
  fetchData: () => void;
}
export default class BlockComponent extends React.Component<BlockProps, {}> {

  constructor(props) {
    super(props);
  }

  public shouldComponentUpdate(nextProps) {
    if (this.props.cursorsTree.hasSelection) {
      return true;
    }
    if (nextProps.cursorsTree.hasSelection) {
      return true;
    }
    if (nextProps.topLevel !== this.props.topLevel) {
      return true;
    }
    if (nextProps.cached !== this.props.cached) {
      return true;
    }
    if (!nextProps.path.is(this.props.path)) {
      // NOTE: this can happen e.g. when you zoom out
      return true;
    }
    if (nextProps.cursorBetween !== this.props.cursorBetween) {
      return true;
    }
    if (nextProps.onCharClick !== this.props.onCharClick) {
      return true;
    }
    if (nextProps.onLineClick !== this.props.onLineClick) {
      return true;
    }
    if (nextProps.onBulletClick !== this.props.onBulletClick) {
      return true;
    }
    // NOTE: it's assumed that session and fetchData never change

    return false;
  }


  public render() {
    const session = this.props.session;
    const parent = this.props.path;
    const cached = this.props.cached;
    const cursorsTree = this.props.cursorsTree;

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
          cursorsTree={cursorsTree}
          cursorBetween={this.props.cursorBetween}
          session={session} path={parent}
          onCharClick={this.props.onCharClick}
          cached={cached}
          onClick={this.props.onLineClick}
        />
      );
      pathElements.push(elLine);
    }

    const children = cached.childRows;
    const collapsed = cached.collapsed;

    if (this.props.topLevel && !children.length) {
      let message = 'Nothing here yet.';
      if (session.mode === 'NORMAL') {
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
             cursorsTree={cursorsTree.getChild(path.row)}
             onCharClick={this.props.onCharClick}
             onLineClick={this.props.onLineClick}
             onBulletClick={this.props.onBulletClick}
             session={session} path={path}
             cursorBetween={this.props.cursorBetween}
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
    if (cursorsTree.visual) {
      className += ' theme-bg-highlight';
    }
    return (
      <div className={className}>
        {pathElements}
      </div>
    );
  }
}
