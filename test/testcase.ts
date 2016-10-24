/* globals afterEach */

import 'mocha';
import * as _ from 'lodash';

import { InMemory } from '../src/assets/js/datastore';
import Document from '../src/assets/js/document';
import Session from '../src/assets/js/session';
import Register from '../src/assets/js/register';
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

type Serialized = any; // TODO

type TestCaseOptions = {
  plugins?: Array<string>
}

class TestCase {
  public store: InMemory;
  protected document: Document;
  protected plugins: Array<string>;
  protected session: Session;
  protected keyhandler: KeyHandler;
  protected register: Register;
  protected pluginManager: PluginsManager;
  protected prom: Promise<void>;

  constructor(serialized: Serialized = [''], options: TestCaseOptions = {}) {
    this.store = new InMemory();
    this.document = new Document(this.store);

    this.plugins = options.plugins;
    this.session = new Session(this.document, {
      bindings: keyBindings,
      viewRoot: Path.root(),
    });

    this.keyhandler = new KeyHandler(this.session, keyBindings);
    this.register = this.session.register;

    this.pluginManager = new PluginsManager(this.session);

    this.prom = Promise.resolve();
    if (this.plugins) {
      this.plugins.forEach((pluginName) => {
        this.enablePlugin(pluginName);
      });
    }

    this._chain(async () => {
      await this.document.load(serialized);

      // this must be *after* plugin loading because of plugins with state
      // e.g. marks needs the database to have the marks loaded
      this.session.cursor =
        new Cursor(this.session, (await this.document.getChildren(Path.root()))[0], 0);
      this.session.reset_history();
      this.session.reset_jump_history();
      // NOTE: HACKY
    });
  }

  protected _chain(next) {
    this.prom = this.prom.then(next);
    return this;
  }

  public done() {
    this.prom = this.prom.then(async () => {
      if (this.plugins) {
        for (let i = 0; i < this.plugins.length; i++) {
          const pluginName = this.plugins[i];
          if (this.pluginManager.getStatus(pluginName) === STATUSES.ENABLED) {
            await this.pluginManager.disable(pluginName);
          }
        }
      }
    });
    return this.prom;
  }

  protected _expectDeepEqual(actual, expected, message) {
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

  protected _expectEqual(actual, expected, message) {
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

  public sendKeys(keys) {
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

  public sendKey(key) {
    return this.sendKeys([key]);
  }

  public import(content, mimetype) {
    return this._chain(() => {
      return this.session.importContent(content, mimetype);
    });
  }

  public enablePlugin(pluginName) {
    return this._chain(async () => {
      return await this.pluginManager.enable(pluginName);
    });
  }

  public disablePlugin(pluginName) {
    return this._chain(async () => {
      return await this.pluginManager.disable(pluginName);
    });
  }

  public expect(expected) {
    return this._chain(async () => {
      const serialized = await this.document.serialize(this.document.root.row, {pretty: true});
      this._expectDeepEqual(serialized.children, expected, 'Unexpected serialized content');
    });
  }

  public expectViewRoot(expected) {
    return this._chain(() => {
      this._expectEqual(this.session.viewRoot.row, expected,
                        'Unexpected view root');
    });
  }

  public expectCursor(row, col) {
    return this._chain(() => {
      this._expectEqual(this.session.cursor.row, row,
                        'Unexpected cursor row');
      this._expectEqual(this.session.cursor.col, col,
                        'Unexpected cursor col');
    });
  }

  public expectJumpIndex(index, historyLength = null) {
    return this._chain(() => {
      this._expectEqual(this.session.jumpIndex, index,
                        'Unexpected jump index');
      if (historyLength !== null) {
        this._expectEqual(this.session.jumpHistory.length, historyLength,
                          'Unexpected jump history length');
      }
    });
  }

  public expectNumMenuResults(num_results) {
    return this._chain(() => {
      this._expectEqual(this.session.menu.results.length, num_results,
                        'Unexpected number of results');
    });
  }

  public setRegister(value) {
    this.register.deserialize(value);
    return this;
  }

  public expectRegister(expected) {
    return this._chain(() => {
      let current = this.register.serialize();
      this._expectDeepEqual(current, expected,
                            'Unexpected register content');
    });
  }

  public expectRegisterType(expected) {
    return this._chain(() => {
      let current = this.register.serialize();
      this._expectDeepEqual(current.type, expected,
                            'Unexpected register type');
    });
  }

  public expectExport(fileExtension, expected) {
    return this._chain(async () => {
      let content = await this.session.exportContent(fileExtension);
      this._expectEqual(content, expected,
                        'Unexpected export content');
    });
  }
}

export default TestCase;
