import * as React from 'react';

import LineComponent, { LineProps } from './line';
import Spinner from './spinner';

import Session from '../session';
import { CachedRowInfo } from '../document';
import Path from '../path';
import { CursorsInfoTree } from '../cursor';
import { Col } from '../types';
import { PartialUnfolder, Token } from '../utils/token_unfolder';
import { getStyles } from '../themes';

type RowProps = {
  session: Session;
  path: Path;
  cached: CachedRowInfo;
  onCharClick: ((path: Path, column: Col, e: Event) => void) | undefined;
  onClick: ((path: Path) => void) | undefined;
  style: React.CSSProperties;
  cursorsTree: CursorsInfoTree;
  cursorBetween: boolean;
};
class RowComponent extends React.Component<RowProps, {}> {
  private onClick: (() => void) | undefined = undefined;
  private onCharClick: ((column: Col, e: Event) => void) | undefined = undefined;

  constructor(props: RowProps) {
    super(props);
    this.init(props);
  }

  private init(props: RowProps) {
    if (props.onClick) {
      this.onClick = () => {
        if (!props.onClick) {
          throw new Error('onClick disappeared');
        }
        props.onClick(props.path);
      };
    }

    if (props.onCharClick) {
      this.onCharClick = (column: Col, e: Event) => {
        if (!props.onCharClick) {
          throw new Error('onCharClick disappeared');
        }
        props.onCharClick(props.path, column, e);
      };
    }
  }

  public componentWillReceiveProps(props: RowProps) {
    this.init(props);
  }

  public render() {
    const session = this.props.session;
    const path = this.props.path;
    const lineData = this.props.cached.line;
    const cursorsTree = this.props.cursorsTree;

    const cursors: {[col: number]: boolean} = {};
    let has_cursor = false;
    const highlights: {[col: number]: boolean} = {};
    let has_highlight = false;

    if (cursorsTree.cursor != null) {
      cursors[cursorsTree.cursor] = true;
      has_cursor = true;
    }
    // TODO: Object.keys alternative that returns Array<number>?
    (Object.keys(cursorsTree.selected)).forEach((col: any) => {
      highlights[col] = true;
      has_highlight = true;
    });
    // TODO: React.ReactNode vs React.ReactElement<any>?
    const results: Array<React.ReactNode> = [];

    let lineoptions: LineProps = {
      lineData,
      cursors,
      cursorStyle: getStyles(session.clientStore, ['theme-cursor']),
      highlights,
      highlightStyle: getStyles(session.clientStore, ['theme-bg-highlight']),
      linksStyle: getStyles(session.clientStore, ['theme-link']),
      accentStyle: getStyles(session.clientStore, ['theme-text-accent']),
      cursorBetween: this.props.cursorBetween,
    };

    const hooksInfo = {
      path, pluginData: this.props.cached.pluginData,
      has_cursor, has_highlight
    };

    lineoptions.lineHook = PartialUnfolder.trivial<Token, React.ReactNode>();
    lineoptions.lineHook = session.applyHook(
      'renderLineTokenHook', lineoptions.lineHook, hooksInfo
    );

    lineoptions.wordHook = PartialUnfolder.trivial<Token, React.ReactNode>();
    lineoptions.wordHook = session.applyHook(
      'renderWordTokenHook', lineoptions.wordHook, hooksInfo
    );

    lineoptions = session.applyHook('renderLineOptions', lineoptions, hooksInfo);
    let lineContents = [
      <LineComponent key='line'
        onCharClick={this.onCharClick}
        {...lineoptions}
      />,
    ];
    lineContents = session.applyHook('renderLineContents', lineContents, hooksInfo);
    results.push(...lineContents);

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
  onCharClick: ((path: Path, column: Col, e: Event) => void) | undefined;
  onLineClick: ((path: Path) => void) | undefined;
  onBulletClick: ((path: Path) => void) | undefined;
  topLevel: boolean;
  fetchData: () => void;
};
export default class BlockComponent extends React.Component<BlockProps, {}> {

  constructor(props: BlockProps) {
    super(props);
  }

  public shouldComponentUpdate(nextProps: BlockProps) {
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

    const style = {};
    if (cursorsTree.visual) {
      Object.assign(style, getStyles(session.clientStore, ['theme-bg-highlight']));
    }
    return (
      <div className='node' style={style}>
        {pathElements}
      </div>
    );
  }
}
