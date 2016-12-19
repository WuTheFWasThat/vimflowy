/* globals afterEach */

import 'mocha';
import * as _ from 'lodash';

import { InMemory } from '../src/assets/js/datastore';
import Document from '../src/assets/js/document';
import Session from '../src/assets/js/session';
import Register, { RegisterTypes, SerializedRegister } from '../src/assets/js/register';
import '../src/assets/js/definitions';
import makeDefaultBindings from '../src/assets/js/keyBindings';
import KeyHandler from '../src/assets/js/keyHandler';
import logger, * as Logger from '../src/assets/js/logger';
import { PluginsManager, PluginStatus } from '../src/assets/js/plugins';
import Cursor from '../src/assets/js/cursor';
import Path from '../src/assets/js/path';
import { SerializedBlock, Row, Col, Key } from '../src/assets/js/types';

// logger.setLevel(Logger.LEVEL.DEBUG);
logger.setStream(Logger.STREAM.QUEUE);
afterEach('empty the queue', () => logger.empty());

// share keybindings across tests, for efficiency
// note that the bindings will change when plugins are enabled and disabled
// thus, tests are not totally isolated
const keyBindings = makeDefaultBindings();

type TestCaseOptions = {
  plugins?: Array<string>
};

class TestCase {
  public store: InMemory;
  protected document: Document;
  protected plugins: Array<string>;
  protected session: Session;
  protected keyhandler: KeyHandler;
  protected register: Register;
  protected pluginManager: PluginsManager;
  protected prom: Promise<void>;

  constructor(serialized: Array<SerializedBlock> = [''], options: TestCaseOptions = {}) {
    this.store = new InMemory();
    this.document = new Document(this.store);

    this.plugins = options.plugins || [];
    this.session = new Session(this.document, {
      bindings: keyBindings,
      viewRoot: Path.root(),
    });

    this.keyhandler = new KeyHandler(this.session, keyBindings);
    this.register = this.session.register;

    this.pluginManager = new PluginsManager(this.session);

    this.prom = Promise.resolve();
    this.plugins.forEach((pluginName) => {
      this.enablePlugin(pluginName);
    });

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

  protected _chain(next: () => void, waitKeyHandler = true) {
    this.prom = this.prom.then(async () => {
      if (waitKeyHandler) {
        await this.keyhandler.chain(async () => {
          await next();
        });
      } else {
        await next();
      }
    });
    return this;
  }

  public done() {
    this.keyhandler.chain(async() => {
      this.prom = this.prom.then(async () => {
        if (this.plugins) {
          for (let i = 0; i < this.plugins.length; i++) {
            const pluginName = this.plugins[i];
            if (this.pluginManager.getStatus(pluginName) === PluginStatus.ENABLED) {
              await this.pluginManager.disable(pluginName);
            }
          }
        }
      });
    });
    return this.prom;
  }

  protected _expectDeepEqual<T>(actual: T, expected: T, message: string) {
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

  protected _expectEqual<T>(actual: T, expected: T, message: string) {
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

  public sendKeys(keysInput: string | Array<Key>) {
    let keys: Array<Key>;
    if (typeof keysInput === 'string') {
      keys = keysInput.split('');
    } else {
      keys = keysInput;
    }

    this._chain(() => {
      keys.forEach((key) => {
        this.keyhandler.queueKey(key);
      });
    }, false);
    return this;
  }

  public sendKey(key: Key) {
    return this.sendKeys([key]);
  }

  public import(content: any, mimetype: string) {
    return this._chain(() => {
      return this.session.importContent(content, mimetype);
    });
  }

  public enablePlugin(pluginName: string) {
    return this._chain(async () => {
      return await this.pluginManager.enable(pluginName);
    });
  }

  public disablePlugin(pluginName: string) {
    return this._chain(async () => {
      return await this.pluginManager.disable(pluginName);
    });
  }

  public expect(expected: Array<SerializedBlock>) {
    return this._chain(async () => {
      const serialized: any = await this.document.serialize(this.document.root.row, {pretty: true});
      this._expectDeepEqual(serialized.children, expected, 'Unexpected serialized content');
    });
  }

  public expectViewRoot(expected: Row) {
    return this._chain(() => {
      this._expectEqual(this.session.viewRoot.row, expected,
                        'Unexpected view root');
    });
  }

  public expectCursor(row: Row, col: Col) {
    return this._chain(() => {
      this._expectEqual(this.session.cursor.row, row,
                        'Unexpected cursor row');
      this._expectEqual(this.session.cursor.col, col,
                        'Unexpected cursor col');
    });
  }

  public expectJumpIndex(index: number, historyLength: number | null = null) {
    return this._chain(() => {
      this._expectEqual(this.session.jumpIndex, index,
                        'Unexpected jump index');
      if (historyLength !== null) {
        this._expectEqual(this.session.jumpHistory.length, historyLength,
                          'Unexpected jump history length');
      }
    });
  }

  public expectNumMenuResults(num_results: number) {
    return this._chain(() => {
      if (this.session.menu === null) {
        throw new Error('Menu was null while expecting menu results');
      }
      this._expectEqual(this.session.menu.results.length, num_results,
                        'Unexpected number of results');
    });
  }

  public setRegister(value: SerializedRegister) {
    this.register.deserialize(value);
    return this;
  }

  public expectRegister(expected: SerializedRegister) {
    return this._chain(() => {
      let current = this.register.serialize();
      this._expectDeepEqual(current, expected, 'Unexpected register content');
    });
  }

  public expectRegisterType(expected: RegisterTypes) {
    return this._chain(() => {
      let current = this.register.serialize();
      this._expectDeepEqual(current.type, expected, 'Unexpected register type');
    });
  }

  public expectExport(mimeType: string, expected: string) {
    return this._chain(async () => {
      let content = await this.session.exportContent(mimeType);
      this._expectEqual(content, expected, 'Unexpected export content');
    });
  }
}

export default TestCase;
