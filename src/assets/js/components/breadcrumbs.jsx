import React from 'react';

// import Spinner from './spinner';

class CrumbComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      onClick: React.PropTypes.func,
      path: React.PropTypes.any,
    };
  }

  render() {
    const session = this.props.session;
    const path = this.props.path;

    let className = '';
    if (this.props.onClick) {
      className = 'theme-text-link';
    }
    return (
      <span key={'crumb_' + path.row} className='crumb'>
        <span className={className} onClick={this.props.onClick}>
          {
            (() => {
              if (path.is(session.document.root)) {
                return <icon className='fa fa-home'/>;
              } else {
                return session.document.getText(path.row).join('');
              }
            })()
          }
        </span>
      </span>
    );
  }
}

export default class BreadcrumbsComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
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
    const session = this.props.session;

    const crumbs = [];
    let path = session.viewRoot;
    while (!path.is(session.document.root)) {
      crumbs.push(path);
      path = path.parent;
    }

    const makeCrumb = (path) => {
      return (
        <CrumbComponent key={path.row}
          session={session} path={path}
          onClick={this.props.onCrumbClick && this.props.onCrumbClick.bind(this, path)}
        />
      );
    };

    const crumbNodes = [];
    crumbNodes.push(makeCrumb(session.document.root));
    for (let i = crumbs.length - 1; i > 0; i--) {
      path = crumbs[i];
      crumbNodes.push(makeCrumb(path));
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
