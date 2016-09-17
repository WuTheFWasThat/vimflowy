import * as React from 'react';

import * as constants from './constants';
// import { Document } from './document';
// import * as DataStore from './datastore';
// import Session from './session';
// import { KeyStream } from './keyHandler';

export const PropType = React.PropTypes.number;

enum HotkeyType {
  NORMAL_MODE_TYPE,
  INSERT_MODE_TYPE
}
type Session = any;
type KeyStream = any;

type ModeMetadata = {
  name: string;
  description: string;
  hotkey_type: HotkeyType;
  // whether only within-row motions are supported
  within_row?: boolean;

  // a list of functions taking a key and context
  //   (key, context) -> [key, context]
  // if the key should be ignored, return it as null (in which case
  // other functions won't receive the key)
  //
  // the functions are called in the order they're registered
  key_transforms?: Array<(key: string, context: any) => [string, any]>;

  // function taking session, upon entering mode
  enter?: (session: Session) => Promise<void>;
  // function executed on every action, while in the mode.
  // takes session and keystream
  every?: (session: Session, keyStream: KeyStream) => Promise<void>;
  // function taking session, upon exiting mode
  exit?: (session: Session) => Promise<void>;

  // a function taking a context and returning a new context
  // in which definition functions will be executed
  // (this is called right before execution)
  transform_context?: (context: any) => any;
};

export default class Mode {
  public metadata: ModeMetadata;
  public name: string;

  constructor(metadata) {
    this.metadata = metadata;
    this.name = metadata.name;
  }

  // function taking session, upon entering mode
  public async enter(session: Session): Promise<void> {
    if (this.metadata.enter) {
      return await this.metadata.enter(session);
    }
  }

  // function executed on every action, while in the mode.
  // takes session and keystream
  public async every(session: Session, keyStream: KeyStream): Promise<void> {
    if (this.metadata.every) {
      return await this.metadata.every(session, keyStream);
    }
  }
  // function taking session, upon exiting mode
  public async exit(session: Session): Promise<void> {
    if (this.metadata.exit) {
      return await this.metadata.exit(session);
    }
  }
  // a function taking a context and returning a new context
  // in which definition functions will be executed
  // (this is called right before execution)
  public transform_context(context: any): any {
    if (this.metadata.transform_context) {
      return this.metadata.transform_context(context);
    }
    return context;
  }

  public transform_key(key, context) {
    if (this.metadata.key_transforms) {
      for (let i = 0; i < this.metadata.key_transforms.length; i++) {
        const key_transform = this.metadata.key_transforms[i];
        [key, context] = key_transform(key, context);
        if (key === null) {
          break;
        }
      }
    }
    return [key, context];
  }

  public handle_bad_key(keyStream: KeyStream): void {
    // for normal mode types, single bad key -> forgotten sequence
    if (this.metadata.hotkey_type === HotkeyType.NORMAL_MODE_TYPE) {
      return keyStream.forget();
    } else {
      return keyStream.forget(1);
    }
  }

};

// an enum dictionary,
const MODES_ENUM = {};
// mapping from mode name to the actual mode object
const MODES = {};
const MODE_TYPES = {};
MODE_TYPES[HotkeyType.NORMAL_MODE_TYPE] = {
  description:
    'Modes in which text is not being inserted, and all keys are configurable as commands.  ' +
    'NORMAL, VISUAL, and VISUAL_LINE modes fall under this category.',
  modes: [],
};
MODE_TYPES[HotkeyType.INSERT_MODE_TYPE] = {
  description:
    'Modes in which most text is inserted, and available hotkeys are restricted to those with modifiers.  ' +
    'INSERT, SEARCH, and MARK modes fall under this category.',
  modes: [],
};

let modeCounter = 1;
const registerMode = function(metadata) {

  // if (MODES_ENUM[metadata.name]) {
  //   // NOTE: re-registration of the mode currently happens in unit tests
  //   // TODO figure this out better.  also tests shouldn't keep registering new modes anyways
  //   return MODES[MODES_ENUM[metadata.name]]
  // }
  const mode = new Mode(metadata);
  MODES_ENUM[metadata.name] = modeCounter;
  MODES[modeCounter] = mode;
  MODE_TYPES[metadata.hotkey_type].modes.push(modeCounter);
  modeCounter += 1;
  return mode;
};

const deregisterMode = function(mode) {
  modeCounter = MODES_ENUM[mode.name];
  delete MODES_ENUM[mode.name];
  delete MODES[modeCounter];
  const index = MODE_TYPES[mode.metadata.hotkey_type].modes.indexOf(modeCounter);
  return MODE_TYPES[mode.metadata.hotkey_type].modes.splice(index, 1);
};

const transform_insert_key = function(key) {
  if (key === 'shift+enter') {
    key = '\n';
  } else if (key === 'space' || key === 'shift+space') {
    key = ' ';
  }
  return key;
};

registerMode({
  name: 'NORMAL',
  hotkey_type: HotkeyType.NORMAL_MODE_TYPE,
  async enter(session) {
    await session.cursor.backIfNeeded();
  },
  key_transforms: [
    function(key, context) {
      let newrepeat;
      [newrepeat, key] = context.keyHandler.getRepeat(context.keyStream, key);
      context.repeat = context.repeat * newrepeat;
      if (key === null) {
        context.keyStream.wait();
      }
      return [key, context];
    },
  ],
});
registerMode({
  name: 'INSERT',
  hotkey_type: HotkeyType.INSERT_MODE_TYPE,
  key_transforms: [
    function(key, context) {
      key = transform_insert_key(key);
      if (key.length === 1) {
        // simply insert the key
        const obj = {char: key};
        for (let i = 0; i < constants.text_properties.length; i++) {
          const property = constants.text_properties[i];
          if (context.session.cursor.getProperty(property)) { obj[property] = true; }
        }
        context.session.addCharsAtCursor([obj]);
        return [null, context];
      }
      return [key, context];
    },
  ],
});

registerMode({
  name: 'VISUAL',
  hotkey_type: HotkeyType.NORMAL_MODE_TYPE,
  async enter(session) {
    return session.anchor = session.cursor.clone();
  },
  async exit(session) {
    return session.anchor = null;
  },
});

registerMode({
  name: 'VISUAL_LINE',
  hotkey_type: HotkeyType.NORMAL_MODE_TYPE,
  async enter(session) {
    session.anchor = session.cursor.clone();
    return session.lineSelect = true;
  },
  async exit(session) {
    session.anchor = null;
    return session.lineSelect = false;
  },
  transform_context(context) {
    const { session } = context;
    const [parent, index1, index2] = session.getVisualLineSelections();
    context.row_start_i = index1;
    context.row_end_i = index2;
    context.row_start = (session.document.getChildren(parent))[index1];
    context.row_end = (session.document.getChildren(parent))[index2];
    context.parent = parent;
    context.num_rows = (index2 - index1) + 1;
    return context;
  },
});

registerMode({
  name: 'SETTINGS',
  hotkey_type: HotkeyType.NORMAL_MODE_TYPE,
  // TODO: exit settings on any bad key press?
});

registerMode({
  name: 'SEARCH',
  hotkey_type: HotkeyType.INSERT_MODE_TYPE,
  within_row: true,
  async every(session, keyStream) {
    session.menu.update();
    return keyStream.forget();
  },
  async exit(session) {
    session.menu = null;
  },
  key_transforms: [
    function(key, context) {
      key = transform_insert_key(key);
      if (key.length === 1) {
        context.session.menu.session.addCharsAtCursor([{char: key}]);
        context.session.menu.update();
        context.keyStream.forget();
        return [null, context];
      }
      return [key, context];
    },
  ],
});

const getMode = mode => MODES[mode];

export {
  registerMode,
  deregisterMode,
  MODES_ENUM as modes,
  MODE_TYPES as types,
  getMode,
  HotkeyType,
};
