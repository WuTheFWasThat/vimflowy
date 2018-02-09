import Session, { InMemorySession } from './session';
import { Line } from './types';

/*
Represents the menu shown in menu mode.
Functions for paging through and selecting results, and for rendering.
Internally uses an entire session object (this is sorta weird..)
*/

export type MenuResult = {
  contents: Line;

  // called when selected
  fn: any; // TODO

  // props for rendering LineComponent
  renderOptions?: {
    accents: {[column: number]: boolean}
  };

  // hook for rendering search result contents
  renderHook?: (line: any) => any; // TODO
};

type Query = string;
type SearchFn = (query: Query) => Promise<Array<MenuResult>>;

export default class Menu {
  private searchFn: SearchFn;
  public results: Array<MenuResult>;
  public selection: number;

  public session: Session;

  private lastQuery: Query | null = null;

  constructor(searchFn: SearchFn) {
    this.searchFn = searchFn;

    // a bit of a overkill-y hack, use an entire session object internally
    this.session = new InMemorySession({ initialMode: 'INSERT' });
    this.selection = 1;

    this.results = [];
  }

  public up() {
    if (!this.results.length) {
      return;
    }
    if (this.selection <= 0) {
      this.selection = this.results.length - 1;
    } else {
      this.selection = this.selection - 1;
    }
  }

  public down() {
    if (!this.results.length) {
      return;
    }
    if (this.selection + 1 >= this.results.length) {
      this.selection = 0;
    } else {
      this.selection = this.selection + 1;
    }
  }

  public async update() {
    const query = await this.session.curText();
    if ((JSON.stringify(query)) !== (JSON.stringify(this.lastQuery))) {
      this.lastQuery = query;
      // const t = Date.now();
      // console.log('updating results');
      this.results = await this.searchFn(query);
      // console.log('updating results took', Date.now() - t);
      this.selection = 0;
    }
  }

  public async select() {
    if (!this.results.length) {
      return;
    }
    const result = this.results[this.selection];
    await result.fn();
  }
}
