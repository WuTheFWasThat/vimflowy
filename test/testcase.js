/* globals afterEach */

import 'blanket';
import _ from 'lodash';

import * as DataStore from '../src/assets/js/datastore';
import Document from '../src/assets/js/document';
import Session from '../src/assets/js/session';
import '../src/assets/js/definitions';
import KeyDefinitions from '../src/assets/js/keyDefinitions';
import KeyBindings from '../src/assets/js/keyBindings';
import KeyHandler from '../src/assets/js/keyHandler';
import logger, * as Logger from '../src/assets/js/logger';
import { PluginsManager, STATUSES } from '../src/assets/js/plugins';
import Cursor from '../src/assets/js/cursor';
import Path from '../src/assets/js/path';

logger.setStream(Logger.STREAM.QUEUE);
afterEach('empty the queue', () => logger.empty());

// share keybindings across tests, for efficiency
// note that the bindings will change when plugins are enabled and disabled
// thus, tests are not totally isolated
let keyBindings = new KeyBindings(KeyDefinitions.clone());

class TestCase {
  constructor(serialized = [''], options = {}) {
    this.store = new DataStore.InMemory();
    this.document = new Document(this.store);

    this.plugins = options.plugins;
    this.session = new Session(this.document, {
      bindings: keyBindings,
      viewRoot: Path.root(),
    });

    this.keyhandler = new KeyHandler(this.session, keyBindings);
    this.register = this.session.register;

    this.pluginManager = new PluginsManager(this.session);
    if (this.plugins) {
      this.plugins.forEach((pluginName) => this.pluginManager.enable(pluginName));
    }

    this.prom = this.document.load(serialized).then(() => {
      // this must be *after* plugin loading because of plugins with state
      // e.g. marks needs the database to have the marks loaded
      this.session.cursor =
        new Cursor(this.session, this.document.getChildren(Path.root())[0], 0);
      this.session.reset_history();
      this.session.reset_jump_history();
      // NOTE: HACKY
    });
  }

  _chain(next) {
    this.prom = this.prom.then(next);
    return this;
  }

  done() {
    this.prom = this.prom.then(() => {
      if (this.plugins) {
        this.plugins.forEach((pluginName) => {
          if (this.pluginManager.getStatus(pluginName) === STATUSES.ENABLED) {
            this.pluginManager.disable(pluginName);
          }
        });
      }
    });
    return this.prom;
  }

  _expectDeepEqual(actual, expected, message) {
    if (!_.isEqual(actual, expected)) {
      logger.flush();
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
      logger.flush();
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
      this._chain(async () =>  {
        await this.keyhandler.handleKey(key);
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
    return this._chain(async () => {
      const serialized = await this.document.serialize(this.document.root.row, {pretty: true});
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
    return this._chain(async () => {
      let content = await this.session.exportContent(fileExtension);
      this._expectEqual(content, expected,
                        'Unexpected export content');
    });
  }
}

export default TestCase;
