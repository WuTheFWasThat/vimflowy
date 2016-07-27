/* globals afterEach */

import 'blanket';
import _ from 'lodash';
import fs from 'fs';
import path from 'path';

import * as DataStore from '../assets/js/datastore';
import Document from '../assets/js/document';
import Session from '../assets/js/session';
fs.readdirSync(path.resolve(__dirname, '../assets/js/definitions')).forEach((file) => {
  if (file.match(/.*\.js$/)) {
    require(path.join('../assets/js/definitions', file));
  }
});
import KeyDefinitions from '../assets/js/keyDefinitions';
import KeyBindings from '../assets/js/keyBindings';
import KeyHandler from '../assets/js/keyHandler';
import * as Logger from '../assets/js/logger';
import { PluginsManager } from '../assets/js/plugins';
import Cursor from '../assets/js/cursor';
import Path from '../assets/js/path';

Logger.logger.setStream(Logger.STREAM.QUEUE);
afterEach('empty the queue', () => Logger.logger.empty());

// will have default bindings
let defaultKeyBindings = new KeyBindings(KeyDefinitions.clone());

class TestCase {
  constructor(serialized = [''], options = {}) {
    this.store = new DataStore.InMemory();
    this.document = new Document(this.store);

    let keyBindings;
    if (options.plugins) {
      // TODO: do this less hackily?
      keyBindings = new KeyBindings(KeyDefinitions.clone());
    } else {
      // just share keybindings, for efficiency
      keyBindings = defaultKeyBindings;
    }
    this.session = new Session(this.document, {
      bindings: keyBindings,
      viewRoot: Path.root(),
    });

    this.keyhandler = new KeyHandler(this.session, keyBindings);
    this.register = this.session.register;

    this.pluginManager = new PluginsManager(this.session);
    if (options.plugins) {
      for (let j = 0; j < options.plugins.length; j++) {
        let pluginName = options.plugins[j];
        this.pluginManager.enable(pluginName);
      }
    }

    // this must be *after* plugin loading because of plugins with state
    // e.g. marks needs the database to have the marks loaded
    this.document.load(serialized);
    this.session.cursor =
      new Cursor(this.session, this.document.getChildren(Path.root())[0], 0);
    this.session.reset_history();
    this.session.reset_jump_history();
    // NOTE: HACKY

    this.prom = Promise.resolve();
  }

  _chain(next) {
    this.prom = this.prom.then(next);
    return this;
  }

  done() {
    return this.prom;
  }

  _expectDeepEqual(actual, expected, message) {
    if (!_.isEqual(actual, expected)) {
      Logger.logger.flush();
      console.error(`
        \nExpected:
        \n${JSON.stringify(expected, null, 2)}
        \nBut got:
        \n${JSON.stringify(actual, null, 2)}
      `
      );
      throw new Error(message);
    }
  }

  _expectEqual(actual, expected, message) {
    if (actual !== expected) {
      Logger.logger.flush();
      console.error(`
        \nExpected:
        \n${expected}
        \nBut got:
        \n${actual}
      `
      );
      throw new Error(message);
    }
  }

  sendKeys(keys) {
    if (typeof keys === 'string') {
      keys = keys.split('');
    }
    keys.forEach((key) => {
      this._chain(() =>  {
        return this.keyhandler.handleKey(key);
      });
    });
    return this;
  }

  sendKey(key) {
    return this.sendKeys([key]);
  }

  import(content, mimetype) {
    return this._chain(() => {
      return this.session.importContent(content, mimetype);
    });
  }

  enablePlugin(pluginName) {
    return this._chain(() => {
      return this.pluginManager.enable(pluginName);
    });
  }

  disablePlugin(pluginName) {
    return this._chain(() => {
      return this.pluginManager.disable(pluginName);
    });
  }

  expect(expected) {
    return this._chain(() => {
      let serialized = this.document.serialize(
        this.document.root.row, {pretty: true}
      );
      this._expectDeepEqual(serialized.children, expected, 'Unexpected serialized content');
    });
  }

  expectViewRoot(expected) {
    return this._chain(() => {
      this._expectEqual(this.session.viewRoot.row, expected,
                        'Unexpected view root');
    });
  }

  expectCursor(row, col) {
    return this._chain(() => {
      this._expectEqual(this.session.cursor.row, row,
                        'Unexpected cursor row');
      this._expectEqual(this.session.cursor.col, col,
                        'Unexpected cursor col');
    });
  }

  expectJumpIndex(index, historyLength = null) {
    return this._chain(() => {
      this._expectEqual(this.session.jumpIndex, index,
                        'Unexpected jump index');
      if (historyLength !== null) {
        this._expectEqual(this.session.jumpHistory.length, historyLength,
                          'Unexpected jump history length');
      }
    });
  }

  expectNumMenuResults(num_results) {
    return this._chain(() => {
      this._expectEqual(this.session.menu.results.length, num_results,
                        'Unexpected number of results');
    });
  }

  setRegister(value) {
    this.register.deserialize(value);
    return this;
  }

  expectRegister(expected) {
    return this._chain(() => {
      let current = this.register.serialize();
      this._expectDeepEqual(current, expected,
                            'Unexpected register content');
    });
  }

  expectRegisterType(expected) {
    return this._chain(() => {
      let current = this.register.serialize();
      this._expectDeepEqual(current.type, expected,
                            'Unexpected register type');
    });
  }

  expectExport(fileExtension, expected) {
    return this._chain(() => {
      let export_ = this.session.exportContent(fileExtension);
      this._expectEqual(export_, expected,
                        'Unexpected export content');
    });
  }
}

export default TestCase;
