import React from 'react';

import Path from '../path';

type CrumbProps = {
  onClick: ((...args: any[]) => void) | undefined,
};
class CrumbComponent extends React.PureComponent<CrumbProps, {}> {
  public render() {
    let className = '';
    if (this.props.onClick) {
      className = 'theme-text-link';
    }
    return (
      <span>
        <span className={className} onClick={this.props.onClick}>
          {this.props.children}
        </span>
        <i className='fa fa-angle-right'
          style={{marginRight: 15, marginLeft: 15}}/>
      </span>
    );
  }
}

type BreadcrumbsProps = {
  viewRoot: Path;
  crumbContents: {[row: number]: string};
  onCrumbClick: ((...args: any[]) => void) | null;
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
    const crumbNodes: Array<React.ReactNode> = [];
    let path = this.props.viewRoot;
    if (path.parent == null) {
      throw new Error('Shouldn\'t render breadcrumbs at root');
    }
    path = path.parent;
    while (path.parent != null) {
      crumbNodes.push(
        <CrumbComponent key={path.row}
          onClick={this.props.onCrumbClick && this.props.onCrumbClick.bind(this, path)}
        >
          {this.props.crumbContents[path.row]}
        </CrumbComponent>
      );
      path = path.parent;
    }
    crumbNodes.push(
      <CrumbComponent key={path.row}
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
