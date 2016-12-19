import React from 'react';

import LineComponent from './line';
import SpinnerComponent from './spinner';
import Session from '../session';
import Menu from '../menu';
import { Line } from '../types';

type Props = {
  session: Session;
  menu: Menu;
};
type State = {
  query: Line | null;
};
export default class MenuComponent extends React.Component<Props, State> {
  private updateFn: () => Promise<void>;
  constructor(props: Props) {
    super(props);
    this.state = {
      query: null,
    };
  }

  public componentDidMount() {
    const menu = this.props.menu;
    this.updateFn = async () => {
      const query = await menu.session.curLine();
      this.setState({ query });
    };
    this.props.session.on('handledKey', this.updateFn);
    this.updateFn();
  }

  public componentWillUnmount() {
    this.props.session.off('handledKey', this.updateFn);
  }

  public render() {
    const menu = this.props.menu;
    const query = this.state.query;

    const searchBox = (
      <div className='searchBox theme-trim'>
        <i className='fa fa-search' style={{'marginRight': 10}}/>
        <span>
          {
            (() => {
              if (query === null) {
                return <SpinnerComponent/>;
              } else {
                return <LineComponent
                  lineData={query}
                  cursors={{
                    [menu.session.cursor.col]: true,
                  }}
                  cursorBetween={true}
                />;
              }
            })()
          }
        </span>
      </div>
    );

    let searchResults;

    if (menu.results.length === 0) {
      let message = '';
      if (!(query && query.length)) {
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
          <LineComponent key={`line_${i}`}
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

