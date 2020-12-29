import * as React from 'react';

import { promiseDebounce } from '../utils/functional';
import logger from '../../../shared/utils/logger';

import * as Modes from '../modes';
import BreadcrumbsComponent from './breadcrumbs';
import BlockComponent from './block';
import Spinner from './spinner';
import Session from '../session';
import { Col } from '../types';
import Path from '../path';
import { CursorsInfoTree } from '../cursor';

// TODO: move mode-specific logic into mode render functions

type Props = {
  session: Session;
};
type State = {
  loaded: boolean;

  // set after data is loaded
  cursorsTree?: CursorsInfoTree;
  crumbContents?: {[row: number]: string };
};

type Profiler = (profilerMessage: string) => () => void;

export default class SessionComponent extends React.Component<Props, State> {
  private update: () => void; // this is promise debounced

  private profileRender: boolean; // for debugging
  private getProfiler: (profileRender: boolean) => Profiler;
  private onCharClick: (path: Path, column: number, e: Event) => void;
  private onLineClick: (path: Path) => Promise<void>;
  private onBulletClick: (path: Path) => Promise<void>;
  private onCrumbClick: (path: Path) => Promise<void>;

  constructor(props: Props) {
    super(props);
    this.state = {
      loaded: false,
    };

    this.onCharClick = (path, column, e) => {
      const session = this.props.session;

      // NOTE: this is fire and forget
      session.cursor.setPosition(path, column).then(() => {
        this.update();
      });

      // prevent overall path click
      e.stopPropagation();
      return false;
    };

    this.onLineClick = async (path) => {
      const session = this.props.session;

      // if clicking outside of text, but on the row,
      // move cursor to the end of the row
      let col = this.cursorBetween() ? -1 : -2;
      await session.cursor.setPosition(path, col);
      this.update();
    };

    this.onBulletClick = async (path) => {
      const session = this.props.session;

      await session.toggleBlockCollapsed(path.row);
      session.save();
      this.update();
    };

    this.onCrumbClick = async (path) => {
      const session = this.props.session;

      await session.zoomInto(path);
      session.save();
      this.update();
    };

    this.fetchAndRerender = this.fetchAndRerender.bind(this);

    // make true to output time taken to get render contents
    this.profileRender = true;

    this.getProfiler = (profileRender) => {
      if (!profileRender) {
        return () => () => null;
      }

      return (profilerMessage) => {
        const t0 = Date.now();

        return () => {
          logger.info(profilerMessage, Date.now() - t0);
        };
      };
    };

    this.update = promiseDebounce(async () => {
      const session = this.props.session;
      const finishProfiling = this.getProfiler(this.profileRender)('Update took');

      const cursorsTree = new CursorsInfoTree(Path.rootRow());
      const cursor = session.cursor;
      const cursorNode = cursorsTree.getPath(cursor.path);
      cursorNode.markCursor(cursor.col);
      if (session.mode === 'VISUAL_LINE') {
        // mirrors logic of finishes_visual_line in keyHandler.js
        const [parent, index1, index2] = await session.getVisualLineSelections();
        const children = await session.document.getChildRange(parent, index1, index2);
        children.forEach((child) => {
          cursorsTree.getPath(child).markVisual();
        });
      } else if (session.mode === 'VISUAL') {
        const anchor = session.anchor;
        if (anchor.path && cursor.path.is(anchor.path)) {
          const start = Math.min(cursor.col, anchor.col);
          const end = Math.max(cursor.col, anchor.col);
          let cols: Array<Col> = [];
          for (let j = start; j <= end; j++) {
            cols.push(j);
          }
          cursorNode.markCols(cols);
        } else {
          logger.warn('Multiline not yet implemented');
        }
      }

      const crumbContents: {[row: number]: string} = {};
      let path = session.viewRoot;
      while (path.parent != null) {
        path = path.parent;
        crumbContents[path.row] = await session.document.getText(path.row);
      }

      this.setState({
        crumbContents,
        cursorsTree,
        loaded: true,
      });

      finishProfiling();
    });
  }

  private async fetchAndRerender() {
    const session = this.props.session;
    const finishProfiling = this.getProfiler(this.profileRender)('forceLoadTree took');

    await session.document.forceLoadTree(session.viewRoot.row, true);

    finishProfiling();
    this.update();
  }

  public componentWillReceiveProps() {
    this.update();
  }

  public componentDidMount() {
    this.update();
  }

  private cursorBetween() {
    const mode = this.props.session.mode;
    return Modes.getMode(mode).metadata.cursorBetween;
  }

  public render() {
    const session = this.props.session;
    if (!this.state.loaded) { return <Spinner/>; }

    const crumbContents = this.state.crumbContents;
    if (crumbContents == null) {
      throw new Error('crumbContents should have been loaded');
    }

    const cursorsTree = this.state.cursorsTree;
    if (cursorsTree == null) {
      throw new Error('cursorsTree should have been loaded');
    }

    const mode = session.mode;
    const viewRoot = session.viewRoot;
    const cachedRow = session.document.cache.get(viewRoot.row);
    if (cachedRow === null) {
      this.fetchAndRerender();
      return <Spinner/>;
    }

    const cursorBetween = this.cursorBetween();

    let onLineClick: ((path: Path) => void) | undefined = undefined;
    let onCharClick: ((path: Path, column: number, e: Event) => void) | undefined = undefined;
    if (mode === 'NORMAL' ||
        mode === 'INSERT' ||
        mode === 'VISUAL' ||
        mode === 'VISUAL_LINE'
       ) {
      onCharClick = this.onCharClick;
      onLineClick = this.onLineClick;
    }

    let onCrumbClick: ((...args: any[]) => void) | undefined = undefined;
    if (mode === 'NORMAL') {
      onCrumbClick = this.onCrumbClick;
    }

    // TODO: have an extra breadcrumb indicator when not at viewRoot?
    return (
      <div>
        {
          (() => {
            if (viewRoot.isRoot()) {
              return null;
            }
            return [
              <BreadcrumbsComponent key='crumbs'
                session={session}
                viewRoot={viewRoot}
                onCrumbClick={onCrumbClick}
                crumbContents={crumbContents}
              />,
              <hr key='bar' style={{opacity: 0.5, marginBottom: 10}}/>,
            ];
          })()
        }
        <BlockComponent
          session={session}
          cursorsTree={cursorsTree.getPath(viewRoot)}
          cached={session.document.cache.get(viewRoot.row)}
          path={viewRoot}
          cursorBetween={cursorBetween}
          topLevel={true}
          onCharClick={onCharClick}
          onLineClick={onLineClick}
          onBulletClick={this.onBulletClick}
          fetchData={this.fetchAndRerender}
        />
      </div>
    );
  }
}

