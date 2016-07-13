/* globals afterEach */

import 'blanket';
import 'coffee-script/register';
import _ from 'lodash';
import fs from 'fs';
import path from 'path';

import DataStore from '../assets/js/datastore';
import Document from '../assets/js/document';
import Session from '../assets/js/session';
let iterable = fs.readdirSync(path.resolve(__dirname, '../assets/js/definitions'));
for (let i = 0; i < iterable.length; i++) {
  let file = iterable[i];
  if ((file.match(/.*\.js$/)) || (file.match(/.*\.coffee$/))) {
    require(path.join('../assets/js/definitions', file));
  }
}
import KeyDefinitions from '../assets/js/keyDefinitions';
import KeyBindings from '../assets/js/keyBindings';
import KeyHandler from '../assets/js/keyHandler';
import Logger from '../assets/js/logger';
import Plugins from '../assets/js/plugins';

Logger.logger.setStream(Logger.STREAM.QUEUE);
afterEach('empty the queue', () => Logger.logger.empty());

// will have default bindings
let defaultKeyBindings = new KeyBindings((KeyDefinitions.clone()));

class TestCase {
  constructor(serialized = [''], options = {}) {
    this.store = new DataStore.InMemory();
    this.document = new Document(this.store);

    let keyBindings;
    if (options.plugins != null) {
      // TODO: do this less hackily?
      keyBindings = new KeyBindings((KeyDefinitions.clone()));
    } else {
      // just share keybindings, for efficiency
      keyBindings = defaultKeyBindings;
    }
    this.session = new Session(this.document, {bindings: keyBindings});

    this.keyhandler = new KeyHandler(this.session, keyBindings);
    this.register = this.session.register;

    this.pluginManager = new Plugins.PluginsManager(this.session);
    if (options.plugins != null) {
      for (let j = 0; j < options.plugins.length; j++) {
        let pluginName = options.plugins[j];
        this.pluginManager.enable(pluginName);
      }
    }

    // this must be *after* plugin loading because of plugins with state
    // e.g. marks needs the database to have the marks loaded
    this.document.load(serialized);
    this.session.reset_history();
    this.session.reset_jump_history();
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
    for (let j = 0; j < keys.length; j++) {
      let key = keys[j];
      this.keyhandler.handleKey(key);
    }
    return this;
  }

  sendKey(key) {
    this.sendKeys([key]);
    return this;
  }

  import(content, mimetype) {
    return this.session.importContent(content, mimetype);
  }

  expect(expected) {
    let serialized = this.document.serialize(this.document.root.row, {pretty: true});
    this._expectDeepEqual(serialized.children, expected, 'Unexpected serialized content');
    return this;
  }

  expectViewRoot(expected) {
    this._expectEqual(this.session.viewRoot.row, expected, 'Unexpected view root');
    return this;
  }

  expectCursor(row, col) {
    this._expectEqual(this.session.cursor.row, row, 'Unexpected cursor row');
    this._expectEqual(this.session.cursor.col, col, 'Unexpected cursor col');
    return this;
  }

  expectJumpIndex(index, historyLength = null) {
    this._expectEqual(this.session.jumpIndex, index, 'Unexpected jump index');
    if (historyLength !== null) {
      this._expectEqual(this.session.jumpHistory.length, historyLength, 'Unexpected jump history length');
    }
    return this;
  }

  expectNumMenuResults(num_results) {
    this._expectEqual(this.session.menu.results.length, num_results, 'Unexpected number of results');
    return this;
  }

  setRegister(value) {
    this.register.deserialize(value);
    return this;
  }

  expectRegister(expected) {
    let current = this.register.serialize();
    this._expectDeepEqual(current, expected, 'Unexpected register content');
    return this;
  }

  expectRegisterType(expected) {
    let current = this.register.serialize();
    this._expectDeepEqual(current.type, expected, 'Unexpected register type');
    return this;
  }

  expectExport(fileExtension, expected) {
    let export_ = this.session.exportContent(fileExtension);
    this._expectEqual(export_, expected, 'Unexpected export content');
    return this;
  }
}

export default TestCase;
