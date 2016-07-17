/* globals $ */

import * as utils from './utils';
import * as constants from './constants';
// import { Document } from './document';
// import * as DataStore from './datastore';

let NORMAL_MODE_TYPE = 'Normal-like modes';
let INSERT_MODE_TYPE = 'Insert-like modes';

let MODE_SCHEMA = {
  title: 'Mode metadata schema',
  type: 'object',
  required: [ 'name' ],
  properties: {
    name: {
      description: 'Name of the mode',
      pattern: '^[A-Z_]{2,32}$',
      type: 'string'
    },
    description: {
      description: 'Description of the mode',
      type: 'string'
    },
    hotkey_type: { // TODO: get rid of this?
      description: 'Either normal-like or insert-like',
      type: 'string'
    },
    within_row: {
      description: 'Only within-row motions are supported',
      type: 'boolean'
    },
    enter: {
      description: 'Function taking session, upon entering mode',
      type: 'function'
    },
    every: {
      description: 'Function executed on every action, while in the mode.  Takes session and keystream',
      type: 'function'
    },
    exit: {
      description: 'Function taking session, upon entering mode',
      type: 'function'
    },

    key_transforms: {
      description: `a list of functions taking a key and context
  (key, context) -> [key, context]
if the key should be ignored, return it as null (in which case
other functions won't receive the key)

the functions are called in the order they're registered`,
      type: 'array',
      default: [],
      items: {
        type: 'function'
      }
    },
    transform_context: {
      description: `a functions taking a context and returning a new context
in which definition functions will be executed
(this is called right before execution)`,
      type: 'function',
      default(context) { return context; }
    }
  }
};
class Mode {
  constructor(metadata) {
    this.metadata = metadata;
    this.name = metadata.name;
    this.key_transforms = metadata.key_transforms;
    this.transform_context = metadata.transform_context;
  }

  enter(session) {
    if (this.metadata.enter) {
      return this.metadata.enter(session);
    }
  }

  every(session, keyStream) {
    if (this.metadata.every) {
      return this.metadata.every(session, keyStream);
    }
  }

  exit(session) {
    if (this.metadata.exit) {
      return this.metadata.exit(session);
    }
  }

  transform_key(key, context) {
    for (let i = 0; i < this.key_transforms.length; i++) {
      let key_transform = this.key_transforms[i];
      [key, context] = key_transform(key, context);
      if (key === null) {
        break;
      }
    }
    return [key, context];
  }

  handle_bad_key(keyStream) {
    // for normal mode types, single bad key -> forgotten sequence
    if (this.metadata.hotkey_type === NORMAL_MODE_TYPE) {
      return keyStream.forget();
    } else {
      return keyStream.forget(1);
    }
  }
}

// an enum dictionary,
let MODES_ENUM = {};
// mapping from mode name to the actual mode object
const MODES = {};
let MODE_TYPES = {};
MODE_TYPES[NORMAL_MODE_TYPE] = {
  description:
    'Modes in which text is not being inserted, and all keys are configurable as commands.  ' +
    'NORMAL, VISUAL, and VISUAL_LINE modes fall under this category.',
  modes: []
};
MODE_TYPES[INSERT_MODE_TYPE] = {
  description:
    'Modes in which most text is inserted, and available hotkeys are restricted to those with modifiers.  ' +
    'INSERT, SEARCH, and MARK modes fall under this category.',
  modes: []
};

let modeCounter = 1;
let registerMode = function(metadata) {
  utils.tv4_validate(metadata, MODE_SCHEMA, 'mode');
  utils.fill_tv4_defaults(metadata, MODE_SCHEMA);

  let { name } = metadata;
  // if name of MODES_ENUM
  //   # NOTE: re-registration of the mode currently happens in unit tests
  //   #       not sure why, but marks tests fail when not letting it re-register
  //   # TODO figure this out better.  also tests shouldn't keep registering new modes anyways
  //   return MODES[MODES_ENUM[name]]
  let mode = new Mode(metadata);
  MODES_ENUM[name] = modeCounter;
  MODES[modeCounter] = mode;
  MODE_TYPES[metadata.hotkey_type].modes.push(modeCounter);
  modeCounter += 1;
  return mode;
};

let deregisterMode = function(mode) {
  modeCounter = MODES_ENUM[mode.name];
  delete MODES_ENUM[mode.name];
  delete MODES[modeCounter];
  let index = MODE_TYPES[mode.metadata.hotkey_type].modes.indexOf(modeCounter);
  return MODE_TYPES[mode.metadata.hotkey_type].modes.splice(index, 1);
};

let transform_insert_key = function(key) {
  if (key === 'shift+enter') {
    key = '\n';
  } else if (key === 'space' || key === 'shift+space') {
    key = ' ';
  }
  return key;
};

registerMode({
  name: 'NORMAL',
  hotkey_type: NORMAL_MODE_TYPE,
  enter(session) {
    return session.cursor.backIfNeeded();
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
    }
  ]
});
registerMode({
  name: 'INSERT',
  hotkey_type: INSERT_MODE_TYPE,
  key_transforms: [
    function(key, context) {
      key = transform_insert_key(key);
      if (key.length === 1) {
        // simply insert the key
        let obj = {char: key};
        for (let i = 0; i < constants.text_properties.length; i++) {
          let property = constants.text_properties[i];
          if (context.session.cursor.getProperty(property)) { obj[property] = true; }
        }
        context.session.addCharsAtCursor([obj]);
        return [null, context];
      }
      return [key, context];
    }
  ]
});

registerMode({
  name: 'VISUAL',
  hotkey_type: NORMAL_MODE_TYPE,
  enter(session) {
    return session.anchor = session.cursor.clone();
  },
  exit(session) {
    return session.anchor = null;
  }
});

registerMode({
  name: 'VISUAL_LINE',
  hotkey_type: NORMAL_MODE_TYPE,
  enter(session) {
    session.anchor = session.cursor.clone();
    return session.lineSelect = true;
  },
  exit(session) {
    session.anchor = null;
    return session.lineSelect = false;
  },
  transform_context(context) {
    let { session } = context;
    let [parent, index1, index2] = session.getVisualLineSelections();
    context.row_start_i = index1;
    context.row_end_i = index2;
    context.row_start = (session.document.getChildren(parent))[index1];
    context.row_end = (session.document.getChildren(parent))[index2];
    context.parent = parent;
    context.num_rows = (index2 - index1) + 1;
    return context;
  }
});

registerMode({
  name: 'SETTINGS',
  hotkey_type: NORMAL_MODE_TYPE,
  enter(session /*, oldmode */) {
    if (session.settings.mainDiv) {
      session.settings.mainDiv.removeClass('hidden');
      $('#settings-open').addClass('hidden');
      return $('#settings-close').removeClass('hidden');
    }
  },
  exit(session) {
    if (session.settings.mainDiv) {
      session.settings.mainDiv.addClass('hidden');
      $('#settings-open').removeClass('hidden');
      return $('#settings-close').addClass('hidden');
    }
  }
  // TODO: exit settings on any bad key press?
});

registerMode({
  name: 'SEARCH',
  hotkey_type: INSERT_MODE_TYPE,
  within_row: true,
  enter(session) {
    if (session.menuDiv) {
      session.menuDiv.removeClass('hidden');
      return session.mainDiv.addClass('hidden');
    }
  },
  every(session, keyStream) {
    session.menu.update();
    return keyStream.forget();
  },
  exit(session) {
    session.menu = null;
    if (session.menuDiv) {
      session.menuDiv.addClass('hidden');
      return session.mainDiv.removeClass('hidden');
    }
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
    }
  ]
});

let getMode = mode => MODES[mode];

export {
  registerMode,
  deregisterMode,
  MODES_ENUM as modes,
  MODE_TYPES as types,
  getMode,
  NORMAL_MODE_TYPE,
  INSERT_MODE_TYPE
};
