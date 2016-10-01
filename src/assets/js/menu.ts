import Session from './session';
import Document from './document';
import * as DataStore from './datastore';
import * as Modes from './modes';
import * as constants from './constants';
import { Line } from './types';

/*
Represents the menu shown in menu mode.
Functions for paging through and selecting results, and for rendering.
Internally uses an entire session object (this is sorta weird..)
*/

type MenuResult = {
  contents: Line;

  // called when selected
  fn: any; // TODO

  // props for rendering LineComponent
  renderOptions?: any; // TODO
};

type Query = Array<string>;

export default class Menu {
  private searchFn: (query: Query) => Promise<Array<MenuResult>>;
  public results: Array<MenuResult>;
  public selection: number;

  public session: Session;

  private lastQuery: Query;

  constructor(searchFn) {
    this.searchFn = searchFn;

    const doc = new Document(new DataStore.InMemory());
    doc.load(constants.empty_data); // NOTE: should be async but is okay since in-memory

    // a bit of a overkill-y hack, use an entire session object internally
    this.session = new Session(doc);
    // NOTE: this is fire and forget
    // TODO: fix?
    this.session.setMode(Modes.modes.INSERT);
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
      this.results = await this.searchFn(query);
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
