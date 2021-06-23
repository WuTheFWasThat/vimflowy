// import { Document } from './document';
// import * as DataStore from './datastore';
import Session from './session';
import { ActionName, ActionContext } from './keyDefinitions';

import { ModeId, Key } from './types';

export type ModeMetadata = {
  name: string;
  description?: string;
  cursorBetween: boolean;
  // whether only within-row motions are supported
  within_row?: boolean;

  // a list of functions taking a key and context
  //   (key, context) -> [key, context]
  // if the key should be ignored, return it as null (in which case
  // other functions won't receive the key)
  //
  // the functions are called in the order they're registered
  key_transforms?: Array<(key: Key, context: ActionContext) => Promise<[Key | null, ActionContext]>>;

  // function taking session, upon entering mode
  enter?: (session: Session, newMode?: ModeId) => Promise<void>;
  // function executed on every action, while in the mode.
  // takes session and keystream
  beforeEvery?: (actionName: ActionName, context: ActionContext) => Promise<void>;
  // function executed on every action, while in the mode.
  // takes session and keystream
  every?: (actionName: ActionName, context: ActionContext, oldMode: ModeId) => Promise<void>;
  // function taking session, upon exiting mode
  exit?: (session: Session, oldMode?: ModeId) => Promise<void>;

  // a function taking a context and returning a new context
  // in which definition functions will be executed
  // (this is called right before execution)
  transform_context?: (context: ActionContext) => Promise<any>;
};

export default class Mode {
  public metadata: ModeMetadata;
  public name: string;
  public id: ModeId;

  constructor(metadata: ModeMetadata) {
    this.metadata = metadata;
    this.name = metadata.name;
    this.id = metadata.name;
  }

  // function taking session, upon entering mode
  public async enter(session: Session, oldMode?: ModeId): Promise<void> {
    if (this.metadata.enter) {
      return await this.metadata.enter(session, oldMode);
    }
  }

  // function executed on every action, while in the mode.
  // takes session and keystream
  public async every(actionName: ActionName, context: ActionContext, oldMode: ModeId): Promise<void> {
    if (this.metadata.every) {
      return await this.metadata.every(actionName, context, oldMode);
    }
  }

  // function executed on every action, while in the mode.
  // takes session and keystream
  public async beforeEvery(actionName: ActionName, context: ActionContext): Promise<void> {
    if (this.metadata.beforeEvery) {
      return await this.metadata.beforeEvery(actionName, context);
    }
  }

  // function taking session, upon exiting mode
  public async exit(session: Session, newMode?: ModeId): Promise<void> {
    if (this.metadata.exit) {
      return await this.metadata.exit(session, newMode);
    }
  }
  // a function taking a context and returning a new context
  // in which definition functions will be executed
  // (this is called right before execution)
  public async transform_context(context: ActionContext): Promise<any> {
    if (this.metadata.transform_context) {
      return await this.metadata.transform_context(context);
    }
    return context;
  }

  public async transform_key(key: Key | null, context: ActionContext): Promise<[Key | null, ActionContext]> {
    if (this.metadata.key_transforms) {
      for (let i = 0; i < this.metadata.key_transforms.length; i++) {
        if (key == null) {
          break;
        }
        const key_transform = this.metadata.key_transforms[i];
        [key, context] = await key_transform(key, context);
      }
    }
    return [key, context];
  }

};

// mapping from mode name to the actual mode object
export const MODES: {[key: string]: Mode} = {};

const registerMode = function(metadata: ModeMetadata) {
  if (MODES[metadata.name]) {
    throw new Error(`Reregistered mode ${metadata.name}`);
  }
  const mode = new Mode(metadata);
  MODES[metadata.name] = mode;
  return mode;
};

const deregisterMode = function(mode: ModeMetadata) {
  delete MODES[mode.name];
};

export const transform_insert_key = function(key: Key) {
  if (key === 'shift+enter') {
    key = '\n';
  } else if (key === 'space' || key === 'shift+space') {
    key = ' ';
  }
  return key;
};

registerMode({
  name: 'NORMAL',
  cursorBetween: false,
  async enter(session: Session) {
    await session.cursor.backIfNeeded();
  },
  async every(_actionName: ActionName, { keyStream, session }: ActionContext) {
    keyStream.save();
    session.save();
  },
  key_transforms: [
    async function(key, context) {
      let newrepeat;
      [newrepeat, key] = await context.keyHandler.getRepeat(context.keyStream, key);
      context.repeat = context.repeat * newrepeat;
      return [key, context];
    },
  ],
});

export const nonSavingInsertActions: {[key: string]: boolean} = {
  'delete-char-before': true,
  'delete-char-after': true,
};

registerMode({
  name: 'INSERT',
  cursorBetween: true,
  key_transforms: [
    async function(key, context) {
      key = transform_insert_key(key);
      if (key.length === 1) {
        // simply insert the key
        await context.session.addCharsAtCursor([key]);
        await context.session.applyHookAsync('charInserted', {}, { key });
        return [null, context];
      }
      return [key, context];
    },
  ],
  async beforeEvery(actionName: ActionName, { session, keyStream }) {
    if (actionName === 'exit-mode') {
      keyStream.save();
    } else if (!nonSavingInsertActions[actionName]) {
      // NOTE: crucially, this doesn't happen if we transform a key into nothing
      session.save();
    }
  },
  async every(actionName: ActionName, { session }: ActionContext, oldMode) {
    if ((!nonSavingInsertActions[actionName]) &&
        (oldMode === 'INSERT')
       ) {
      // NOTE: crucially, this doesn't happen if we transform a key into nothing
      session.save();
    }
  },
  async enter(session: Session) {
    await session.cursor.setCol(session.cursor.col); // just to call colChange event
  },
  async exit(session: Session) {
    await session.cursor.left();
    // unlike other modes, esc in insert mode keeps changes
    session.save();
  },
});

registerMode({
  name: 'VISUAL',
  cursorBetween: false,
  async enter(session: Session) {
    session.startAnchor();
  },
  async exit(session: Session, newMode?: ModeId) {
    session.stopAnchor();
    // NOTE: should we have keyStream.save()?
    if (newMode === 'NORMAL') {
      session.save();
    }
  },
});

registerMode({
  name: 'VISUAL_LINE',
  cursorBetween: false,
  async enter(session: Session) {
    session.startAnchor();
  },
  async exit(session, newMode?: ModeId) {
    session.stopAnchor();
    // NOTE: should we have keyStream.save()?
    if (newMode === 'NORMAL') {
      session.save();
    }
  },
  async transform_context(context) {
    const { session } = context;
    const [parent, index1, index2] = await session.getVisualLineSelections();
    const children = await session.document.getChildren(parent);
    context.visual_line = {
      start_i: index1,
      end_i: index2,
      start: children[index1],
      end: children[index2],
      parent: parent,
      selected: children.slice(index1, index2 + 1),
      num_rows: (index2 - index1) + 1,
    };
    return context;
  },
});

registerMode({
  name: 'SETTINGS',
  cursorBetween: false,
  // TODO: exit settings on any bad key press?
});

registerMode({
  name: 'SEARCH',
  cursorBetween: true,
  within_row: true,
  async every(_actionName: ActionName, { session, keyStream }) {
    if (session.menu == null) {
      throw new Error('No menu in session');
    }
    await session.menu.update();
    keyStream.drop();
  },
  async exit(session) {
    session.menu = null;
    // NOTE: should keyStream.drop() here?
  },
  key_transforms: [
    async function(key, context) {
      if (context.session.menu == null) {
        throw new Error('No menu in session');
      }
      key = transform_insert_key(key);
      if (key.length === 1) {
        await context.session.menu.session.addCharsAtCursor([key]);
        await context.session.menu.update();
        context.keyStream.drop();
        return [null, context];
      }
      return [key, context];
    },
  ],
});

const getMode: (mode: ModeId) => Mode = (mode: ModeId) => MODES[mode];

export {
  registerMode,
  deregisterMode,
  getMode,
};
