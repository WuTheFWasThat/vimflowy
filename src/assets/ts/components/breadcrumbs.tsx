import * as React from 'react';

import Path from '../path';
import Session from '../session';
import { getStyles } from '../themes';

type CrumbProps = {
  onClick: ((...args: any[]) => void) | undefined,
  session: Session,
};
class CrumbComponent extends React.PureComponent<CrumbProps, {}> {
  public render() {
    const style = {};
    if (this.props.onClick) {
      Object.assign(style, getStyles(this.props.session.clientStore, ['theme-link']));
    }
    return (
      <span>
        <span style={style} onClick={this.props.onClick}>
          {this.props.children}
        </span>
        <i className='fa fa-angle-right'
          style={{marginRight: 15, marginLeft: 15}}/>
      </span>
    );
  }
}

type BreadcrumbsProps = {
  session: Session;
  viewRoot: Path;
  crumbContents: {[row: number]: string};
  onCrumbClick: ((...args: any[]) => void) | undefined;
};
type BreadcrumbsState = {
  loaded: boolean;
};
export default class BreadcrumbsComponent extends React.Component<BreadcrumbsProps, BreadcrumbsState> {
  constructor(props: BreadcrumbsProps) {
    super(props);
    this.state = {
      loaded: false,
    };
  }

  public render() {
    const session = this.props.session;

    const crumbNodes: Array<React.ReactNode> = [];
    let path = this.props.viewRoot;
    if (path.parent == null) {
      throw new Error('Shouldn\'t render breadcrumbs at root');
    }
    path = path.parent;
    while (path.parent != null) {
      const cachedRow = session.document.cache.get(path.row);
      if (!cachedRow) {
        throw new Error('Row wasnt cached despite being in crumbs');
      }
      const hooksInfo = {
        path,
        pluginData: cachedRow.pluginData,
      };

      crumbNodes.push(
        <CrumbComponent key={path.row} session={session}
          onClick={this.props.onCrumbClick && this.props.onCrumbClick.bind(this, path)}
        >
        {
          session.applyHook(
            'renderLineContents',
            [this.props.crumbContents[path.row]],
            hooksInfo
          )
        }
        </CrumbComponent>
      );
      path = path.parent;
    }
    crumbNodes.push(
      <CrumbComponent key={path.row} session={session}
        onClick={this.props.onCrumbClick && this.props.onCrumbClick.bind(this, path)}
      >
        <i className='fa fa-home'/>
      </CrumbComponent>
    );
    crumbNodes.reverse();

    return (
      <div key='breadcrumbs' style={{ fontSize: 20, marginBottom: 10 }} >
        {crumbNodes}
      </div>
    );
  }
}
