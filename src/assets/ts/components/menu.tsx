import * as React from 'react';

import LineComponent from './line';
import SpinnerComponent from './spinner';
import Session from '../session';
import Menu from '../menu';
import { Line, Chars } from '../types';
import { getStyles } from '../themes';

type Props = {
  session: Session;
  menu: Menu;
};
type State = {
  query: Line | null;
};
export default class MenuComponent extends React.Component<Props, State> {
  private updateFn?: () => Promise<void>;
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
    if (!this.updateFn) {
      throw new Error('Unmounting before mounting!?');
    }
    this.props.session.off('handledKey', this.updateFn);
  }

  public render() {
    const menu = this.props.menu;
    const query = this.state.query;
    const session = this.props.session;

    const searchBox = (
      <div className='searchBox' style={{
        ...getStyles(session.clientStore, ['theme-trim']),
      }}>
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
                  cursorStyle={getStyles(session.clientStore, ['theme-cursor'])}
                  highlightStyle={getStyles(session.clientStore, ['theme-bg-highlight'])}
                  linksStyle={getStyles(session.clientStore, ['theme-link'])}
                  accentStyle={getStyles(session.clientStore, ['theme-text-accent'])}
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

      menu.results.sort((a, b) => a.contentsParent.toString().localeCompare(b.contentsParent.toString()));
      let lastParent: Chars;
      searchResults = menu.results.map((result, i) => {
        const selected = i === menu.selection;

        const renderOptions = result.renderOptions || {};
        let contents = (
          <LineComponent key={`line_${i}`}
            lineData={result.contents}
            cursorStyle={getStyles(session.clientStore, ['theme-cursor'])}
            highlightStyle={getStyles(session.clientStore, ['theme-bg-highlight'])}
            linksStyle={getStyles(session.clientStore, ['theme-link'])}
            accentStyle={getStyles(session.clientStore, ['theme-text-accent'])}
            {...renderOptions}
          />
        );
        let contentsParent = result.contentsParent;
        if (result.renderHook) {
          contents = result.renderHook(contents);
        }

        const style = { marginBottom: 10 };
        if (selected) {
          Object.assign(style, getStyles(session.clientStore, ['theme-bg-highlight']));
        }

        let needParentDiv = false;
        lastParent !== contentsParent ? needParentDiv = true : needParentDiv = false;
        lastParent = contentsParent;

        return (
          <div key={`parent_${i}`}>
            {needParentDiv && (
              <div style={{ 'fontWeight': 'bold', 'fontSize': 18, marginBottom: 10 }}>{contentsParent}</div>
            )}
            <div key={i} style={style}>
              <i style={{marginRight: 20}}
                className={`fa ${selected ? 'fa-arrow-circle-right' : 'fa-circle'} bullet`}/>
              {contents}
            </div>
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

