import React from 'react';

import LineComponent from './line.jsx';

export default class MenuComponent extends React.Component {
  static get propTypes() {
    return {
      menu: React.PropTypes.any
    };
  }

  constructor(props) {
    super(props);
  }

  render() {
    const menu = this.props.menu;
    if (!menu) {
      return <div></div>;
    }

    const searchBox = (
      <div className='searchBox theme-trim'>
        <i className='fa fa-search' style={{'marginRight': 10}}/>
        <span>
          <LineComponent
            lineData={
              menu.session.document.getLine(menu.session.cursor.path.row)
            }
            cursors={{
              [menu.session.cursor.col]: true
            }}
            cursorBetween={true}
          />
        </span>
      </div>
    );

    let searchResults;

    if (menu.results.length === 0) {
      let message = '';
      if (menu.session.curLineLength() === 0) {
        message = 'Type something to search!';
      } else {
        message = 'No results!  Try typing something else';
      }
      searchResults = (
        <div style={{fontSize: 20, opacity: 0.5}} className='center'>
          {message}
        </div>
      );
    } else {
      searchResults = menu.results.map((result, i) => {
        const selected = i === menu.selection;

        const renderOptions = result.renderOptions || {};
        let contents = (
          <LineComponent
            lineData={result.contents}
            {...renderOptions}
          />
        );
        if (result.renderHook) {
          contents = result.renderHook(contents);
        }

        const className = selected ? 'theme-bg-selection' : '';
        const icon = selected ? 'fa-arrow-circle-right' : 'fa-circle';
        return (
          <div key={i} style={{marginBottom: 10}} className={className}>
            <i className={`fa ${icon} bullet`} style={{marginRight: 20}}>
            </i>
            {contents}
          </div>
        );
      });
    }

    return (
      <div>
        {searchBox}
        {searchResults}
      </div>
    );
  }
}

