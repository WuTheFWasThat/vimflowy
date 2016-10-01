import React from 'react';

// import Spinner from './spinner';

class CrumbComponent extends React.Component {
  static get propTypes() {
    return {
      onClick: React.PropTypes.func,
      children: React.PropTypes.any,
    };
  }

  render() {
    let className = 'crumb';
    if (this.props.onClick) {
      className += ' theme-text-link';
    }
    return (
      <span className={className} onClick={this.props.onClick}>
        {this.props.children}
      </span>
    );
  }
}

export default class BreadcrumbsComponent extends React.Component {
  static get propTypes() {
    return {
      viewRoot: React.PropTypes.any.isRequired,
      crumbContents: React.PropTypes.any.isRequired,
      onCrumbClick: React.PropTypes.func,
    };
  }

  constructor(props) {
    super(props);
    this.state = {
      loaded: false,
    };
  }

  render() {
    const crumbNodes = [];
    let path = this.props.viewRoot;
    if (path.isRoot()) {
      crumbNodes.push(
        <CrumbComponent key={path.row}>
          <icon className='fa fa-home'/>
        </CrumbComponent>
      );
    } else {
      path = path.parent;
      while (!path.isRoot()) {
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
          <icon className='fa fa-home'/>
        </CrumbComponent>
      );
      crumbNodes.reverse();
    }

    return (
      <div key='breadcrumbs' className='breadcrumbs'
        style={{ fontSize: 20, marginBottom: 10 }}
      >
        {crumbNodes}
      </div>
    );
  }
}
