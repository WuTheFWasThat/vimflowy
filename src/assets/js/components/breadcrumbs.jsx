import React from 'react';

import * as Modes from '../modes';

// import Spinner from './spinner';
import { virtualRenderLine } from './block';

const MODES = Modes.modes;

class CrumbComponent extends React.Component {
  static get propTypes() {
    return {
      session: React.PropTypes.any.isRequired,
      options: React.PropTypes.any,
      path: React.PropTypes.any,
    };
  }

  render() {
    const session = this.props.session;
    const options = this.props.options;
    const path = this.props.path;

    let className = '';
    let onClick = null;
    // TODO: move this logic into mode render functions?
    if (session.mode === MODES.NORMAL) {
      className = 'theme-text-link';
      onClick = async () => {
        await session.zoomInto(path);
        session.save();
        options.rerender();
      };
    }
    return (
      <span key={'crumb_' + path.row} className='crumb'>
        <span className={className} onClick={onClick}>
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
      options: React.PropTypes.any,
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
    const options = this.props.options;

    const crumbs = [];
    let path = session.viewRoot;
    while (!path.is(session.document.root)) {
      crumbs.push(path);
      path = path.parent;
    }

    const makeCrumb = (path, isLast) => {
      if (isLast) {
        return virtualRenderLine(session, path, options);
      } else {
        return (
          <CrumbComponent key={path.row}
            session={session} options={options} path={path}
          />
        );
      }
    };

    const crumbNodes = [];
    crumbNodes.push(makeCrumb(session.document.root));
    for (let i = crumbs.length - 1; i >= 0; i--) {
      path = crumbs[i];
      crumbNodes.push(makeCrumb(path, i===0));
    }

    return (
      <div key='breadcrumbs' className='breadcrumbs'
        style={{
          fontSize: 20,
          marginBottom: 20,
        }}
      >
        {crumbNodes}
      </div>
    );
  }
}
