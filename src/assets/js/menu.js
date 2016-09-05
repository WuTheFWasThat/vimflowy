import Session from './session';
import Document from './document';
import * as DataStore from './datastore';
import * as Modes from './modes';
import * as constants from './constants';

/*
Represents the menu shown in menu mode.
Functions for paging through and selecting results, and for rendering.
Internally uses an entire session object (this is sorta weird..)
*/

export default class Menu {
  constructor(div, fn) {
    this.fn = fn;

    const doc = new Document(new DataStore.InMemory());
    doc.load(constants.empty_data);

    // a bit of a overkill-y hack, use an entire session object internally
    this.session = new Session(doc);
    // NOTE: this is fire and forget
    // TODO: fix?
    this.session.setMode(Modes.modes.INSERT);
    this.selection = 1;

    // list of results:
    //   contents: a line of contents
    //   renderOptions: options for renderLine
    //   fn: call if selected
    this.results = [];
  }

  up() {
    if (!this.results.length) {
      return;
    }
    if (this.selection <= 0) {
      return this.selection = this.results.length - 1;
    } else {
      return this.selection = this.selection - 1;
    }
  }

  down() {
    if (!this.results.length) {
      return;
    }
    if (this.selection + 1 >= this.results.length) {
      return this.selection = 0;
    } else {
      return this.selection = this.selection + 1;
    }
  }

  update() {
    const query = this.session.curText();
    if ((JSON.stringify(query)) !== (JSON.stringify(this.lastquery))) {
      this.lastquery = query;
      this.results = this.fn(query);
      return this.selection = 0;
    }
  }

  async select() {
    if (!this.results.length) {
      return;
    }
    const result = this.results[this.selection];
    return await result.fn();
  }
}
