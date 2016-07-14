import Session from './session.coffee';
import Document from './document.coffee';
import DataStore from './datastore.coffee';
import Modes from './modes.coffee';

/*
Represents the menu shown in menu mode.
Functions for paging through and selecting results, and for rendering.
Internally uses an entire session object (this is sorta weird..)
*/

class Menu {
  constructor(div, fn) {
    this.div = div;
    this.fn = fn;

    let document = new Document((new DataStore.InMemory()));

    // a bit of a overkill-y hack, use an entire session object internally
    this.session = new Session(document);
    this.session.setMode(Modes.modes.INSERT);
    this.selection = 0;

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
    let query = this.session.curText();
    if ((JSON.stringify(query)) !== (JSON.stringify(this.lastquery))) {
      this.lastquery = query;
      this.results = this.fn(query);
      return this.selection = 0;
    }
  }

  select() {
    if (!this.results.length) {
      return;
    }
    let result = this.results[this.selection];
    return result.fn();
  }
}

// exports
export default Menu;
