import * as _ from 'lodash';
import * as React from 'react'; // tslint:disable-line no-unused-variable

import * as errors from '../../shared/utils/errors';
import { Logger } from '../../shared/utils/logger';

import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import Document from '../../assets/ts/document';
import Session, { InMemorySession } from '../../assets/ts/session';
import LineComponent from '../../assets/ts/components/line';
import Mutation from '../../assets/ts/mutations';
import Path from '../../assets/ts/path';
import { Char, Row } from '../../assets/ts/types';
import { getStyles } from '../../assets/ts/themes';

import { SINGLE_LINE_MOTIONS } from '../../assets/ts/definitions/motions';
import { INSERT_MOTION_MAPPINGS } from '../../assets/ts/configurations/vim';
import { motionKey } from '../../assets/ts/keyDefinitions';
import Menu from '../../assets/ts/menu';

// TODO: do this elsewhere
declare const process: any;

type Tag = string;
type Tags = Tag[];
type Rows = Row[];
type TagsToRows = {[key: string]: Rows};
type RowsToTags = {[key: number]: Tags};

const tagStyle = {
  padding: '0px 8px',
  marginLeft: 8,
};

const tagSearchStyle = {
  padding: '0px 8px',
  marginRight: 8,
};

/*
 * ALGORITHMIC NOTE: maintaining the set of tags
 * Rather than trying to update the list
 * as rows get removed and added from the document (which is especially
 * tricky because of cloning),
 * we simply store all tags, even if attached to the document,
 * and then prune after looking them up.
 */

export class TagsPlugin {
  private api: PluginApi;
  private logger: Logger;
  private session: Session;
  private document: Document;
  private tagstate: {
    session: Session,
    path: Path,
  } | null = null;
  // hacky, these are only used when enabled
  public SetTag!: new(row: Row, tag: Tag) => Mutation;
  public UnsetTag!: new(row: Row, tag: Tag) => Mutation;

  constructor(api: PluginApi) {
    this.api = api;
    this.logger = this.api.logger;
    this.session = this.api.session;
    this.document = this.session.document;
    // NOTE: this may not be initialized correctly at first
    // this only affects rendering @taglinks for now
  }

  public async enable() {
    const that = this;
    this.logger.debug('Enabling tags');

    class SetTag extends Mutation {
      private row: Row;
      private tag: Tag;
      private undo: boolean;

      constructor(row: Row, tag: Tag, undo = false) {
        super();
        this.row = row;
        this.tag = tag;
        this.undo = undo;
      }
      public str() {
        return `row ${this.row}, tag ${this.tag}`;
      }
      public async mutate(/* session */) {
        await that._setTag(this.row, this.tag);
        await that.api.updatedDataForRender(this.row);
        if (!this.undo) {
          await that.document.applyHookAsync('tagAdded', {}, { tag: this.tag, row: this.row });
        }
      }
      public async rewind(/* session */) {
        return [
          new UnsetTag(this.row, this.tag, true),
        ];
      }
    }
    this.SetTag = SetTag;

    class UnsetTag extends Mutation {
      private row: Row;
      private tag: Tag;
      private undo: boolean;

      constructor(row: Row, tag: Tag, undo = false) {
        super();
        this.row = row;
        this.tag = tag;
        this.undo = undo;
      }
      public str() {
        return `row ${this.row}, tag ${this.tag}`;
      }
      public async mutate(/* session */) {
        const tags = await that.getTags(this.row);
        if (tags !== null && tags.includes(this.tag)) {
          await that._unsetTag(this.row, this.tag);
          await that.api.updatedDataForRender(this.row);
          if (!this.undo) {
            await that.document.applyHookAsync('tagRemoved', {}, { tag: this.tag, row: this.row });
          }
        }
      }
      public async rewind(/* session */) {
        return [
          new SetTag(this.row, this.tag, true),
        ];
      }
    }
    this.UnsetTag = UnsetTag;

    // Serialization #

    this.api.registerHook('document', 'serializeRow', async (struct, info) => {
      const tags = await this.getTags(info.row);
      if (tags) {
        struct.tags = tags;
      }
      return struct;
    });

    this.api.registerListener('document', 'loadRow', async (path, serialized) => {
      if (serialized.tags != null) {
        const err = await this.setTags(path.row, serialized.tags);
        if (err) { return this.session.showMessage(err, {text_class: 'error'}); }
      }
    });

    // Commands #

    this.tagstate = null;

    this.api.registerMode({
      name: 'TAG',
      cursorBetween: true,
      within_row: true,
      enter: async (session /*, newMode?: ModeId */) => {
        // initialize tags stuff
        this.tagstate = {
          session: new InMemorySession(),
          path: session.cursor.path,
        };
        await this.tagstate.session.setMode('INSERT');
      },
      exit: async (/*session, newMode?: ModeId */) => {
        // do this, now that tagstate is cleared
        if (!this.tagstate) {
          throw new Error('Tag state null during exit');
        }
        const taggedRow = this.tagstate.path.row;
        this.tagstate = null;
        await this.api.updatedDataForRender(taggedRow);
      },
      every: async (/*session*/) => {
        if (!this.tagstate) {
          throw new Error('Tag state null during every');
        }
        await this.api.updatedDataForRender(this.tagstate.path.row);
      },
      key_transforms: [
        async (key, context) => {
          // must be non-whitespace
          if (key.length === 1) {
            if (/^\S*$/.test(key)) {
              if (this.tagstate === null) {
                throw new Error('Tag state null during key transform');
              }
              await this.tagstate.session.addCharsAtCursor([key]);
              await this.api.updatedDataForRender(this.tagstate.path.row);
              return [null, context];
            }
          }
          return [key, context];
        },
      ],
    });

    this.api.registerAction(
      'begin-tag',
      'Tag a line',
      async function({ session }) {
        await session.setMode('TAG');
      },
    );

    this.api.registerAction(
      'finish-tag',
      'Finish typing tag',
      async function({ session, keyStream }) {
        if (that.tagstate === null) {
          throw new Error('Tag state null in tag mode');
        }
        const tag = await that.tagstate.session.curText();
        const taggedRow = that.tagstate.path.row;
        const err = await that.addTag(taggedRow, tag);
        if (err) { session.showMessage(err, {text_class: 'error'}); }
        await session.setMode('NORMAL');
        keyStream.save();
      }
    );

    this.api.registerAction(
      'delete-tag',
      'Delete tag at cursor',
      async function({ session, keyStream }) {
        let err = null;
        const rowsToTags = await that._getRowsToTags();
        const taggedRow = session.cursor.row;
        if (rowsToTags[taggedRow] == null || rowsToTags[taggedRow].length === 0) {
          err = 'Row is not tagged';
        } else {
          let key: Char;
          if (rowsToTags[taggedRow].length === 1) {
            key = '1';
          } else {
            key = await keyStream.dequeue();
          }
          if (key >= '1' && key <= '9') {
            const idx = parseInt(key, 10) - 1;
            if (idx >= rowsToTags[taggedRow].length) {
              err = 'Index out of range';
            } else {
              err = await that.removeTag(session.cursor.row, rowsToTags[taggedRow][idx]);
            }
          } else {
            err = 'Key not a number from 1-9';
          }
        }
        if (err) { session.showMessage(err, {text_class: 'error'}); }
        await session.setMode('NORMAL');
        keyStream.save();
      },
    );

    this.api.registerAction(
      'move-cursor-tag',
      'Move the cursor within the tag being edited (according to the specified motion)',
      async function({ motion }) {
        if (motion == null) {
          throw new Error('Expected a motion!');
        }
        if (that.tagstate === null) {
          throw new Error('Tag state null in tag mode');
        }
        await motion(that.tagstate.session.cursor, {pastEnd: true});
      },
      { acceptsMotion: true },
    );

    this.api.registerAction(
      'tag-delete-char-before',
      'Delete last character (i.e. backspace key)',
      async function() {
        if (that.tagstate === null) {
          throw new Error('Tag state null in tag mode');
        }
        await that.tagstate.session.deleteAtCursor();
      },
    );

    this.api.registerAction(
      'tag-delete-char-after',
      'Delete character at the cursor (i.e. del key)',
      async function() {
        if (that.tagstate === null) {
          throw new Error('Tag state null in tag mode');
        }
        await that.tagstate.session.delCharsAfterCursor(1);
      },
    );

    this.api.registerAction(
      'search-tags',
      'List tagged rows',
      async function({ session }) {
        await session.setMode('SEARCH');
        const tags = await that.listTags();
        session.menu = new Menu(async (text) => {
          // find tags that start with the prefix
          const findTags = async (_document: Document, prefix: string, nresults = 10) => {
            const results: Array<{
              path: Path, tag: Tag,
            }> = []; // list of paths
            for (const tag in tags) {
              if (tag.indexOf(prefix) === 0) {
                const paths = tags[tag];
                for (const path of paths) {
                  results.push({ path, tag });
                  if (nresults > 0 && results.length === nresults) {
                    break;
                  }
                }
              }
            }
            return results;
          };

          return await Promise.all(
            (await findTags(session.document, text)).map(
              async ({ path, tag }) => {
                const line = await session.document.getLine(path.row);
                return {
                  contents: line,
                  renderHook(lineDiv: React.ReactElement<any>) {
                    return (
                      <span key={`tag_${tag}`}>
                        <span
                          style={{
                            ...getStyles(session.clientStore, ['theme-bg-tertiary', 'theme-trim']),
                            ...tagSearchStyle
                          }}
                        >
                          {tag}
                        </span>
                        {lineDiv}
                      </span>
                    );
                  },
                  fn: async () => await session.zoomInto(path),
                };
              }
            )
          );
        });
      }
    );

    this.api.registerDefaultMappings(
      'TAG',
      Object.assign({
        'toggle-help': [['ctrl+?']],
        'move-cursor-tag': [[motionKey]],
        'finish-tag': [['enter']],
        'tag-delete-char-after': [['delete']],
        'tag-delete-char-before': [['backspace'], ['shift+backspace']],
        'exit-mode': [['esc'], ['ctrl+c']],
      }, _.pick(INSERT_MOTION_MAPPINGS, SINGLE_LINE_MOTIONS))
    );

    this.api.registerDefaultMappings(
      'NORMAL',
      {
        'begin-tag': [['#']],
        'delete-tag': [['d', '#']],
        'search-tags': [['-']],
      },
    );

    this.api.registerHook('document', 'pluginRowContents', async (obj, { row }) => {
      const tags = await this.getTags(row);
      const tagging = this.tagstate && (this.tagstate.path.row === row);
      obj.tags = { tags, tagging };
      if (this.tagstate && tagging) {
        obj.tags.tagText = await this.tagstate.session.document.getLine(
          this.tagstate.session.cursor.path.row
        );
        obj.tags.tagCol = this.tagstate.session.cursor.col;
      }
      return obj;
    });

    this.api.registerHook('session', 'renderLineOptions', (options, info) => {
      if (info.pluginData.tags && info.pluginData.tags.tagging) {
        options.cursors = {};
      }
      return options;
    });

    this.api.registerHook('session', 'renderLineContents', (lineContents, info) => {
      const { pluginData } = info;
      if (pluginData.tags) {
        const tags = pluginData.tags.tags;
        if (tags) {
          for (let tag of tags) {
              const key = 'tag-' + tag;
              lineContents.push(
                <span key={key}
                  style={{
                    ...getStyles(this.api.session.clientStore, ['theme-bg-tertiary']),
                    ...tagStyle
                  }}
                >
                  {tag}
                </span>
              );
          }
        }
        if (pluginData.tags.tagging) {
          lineContents.push(
            <span key='editingTag'
              style={{
                ...getStyles(this.api.session.clientStore, ['theme-bg-tertiary', 'theme-trim-accent']),
                ...tagStyle
              }}
            >
              <LineComponent
                lineData={pluginData.tags.tagText}
                cursors={{
                  [pluginData.tags.tagCol]: true,
                }}
                cursorStyle={getStyles(this.api.session.clientStore, ['theme-cursor'])}
                highlightStyle={getStyles(this.api.session.clientStore, ['theme-bg-highlight'])}
                linksStyle={getStyles(this.api.session.clientStore, ['theme-link'])}
                accentStyle={getStyles(this.api.session.clientStore, ['theme-text-accent'])}
                cursorBetween={true}
              />
            </span>
          );
        }
      }
      return lineContents;
    });
  }

  // maintain global tags data structures
  //   a map: row -> tags
  //   and a second map: tag -> rows
  public async _getRowsToTags(): Promise<RowsToTags> {
    return await this.api.getData('ids_to_tags', {});
  }
  private async _setRowsToTags(rows_to_tags: RowsToTags) {
    return await this.api.setData('ids_to_tags', rows_to_tags);
  }
  public async _getTagsToRows(): Promise<TagsToRows> {
    return await this.api.getData('tags_to_ids', {});
  }
  private async _setTagsToRows(tag_to_rows: TagsToRows) {
    return await this.api.setData('tags_to_ids', tag_to_rows);
  }

  private async _sanityCheckTags() {
    if (process.env.NODE_ENV === 'production') {
      return;
    }
    const [
      tags_to_rows,
      rows_to_tags,
    ] = await Promise.all([
      this._getTagsToRows(),
      this._getRowsToTags(),
    ]);
    const tags_to_rows2: TagsToRows = {};
    for (const row in rows_to_tags) {
      const tags = rows_to_tags[row];
      errors.assert(tags.length === new Set(tags).size);
      for (let tag of tags) {
        if (!tags_to_rows2[tag]) {
          tags_to_rows2[tag] = [];
        }
        tags_to_rows2[tag].push(parseInt(row, 10));
      }
    }
    for (const tag in tags_to_rows) {
      tags_to_rows[tag].sort();
      tags_to_rows2[tag].sort();
      errors.assert(tags_to_rows[tag].length === new Set(tags_to_rows[tag]).size);
    }
    errors.assert_deep_equals(tags_to_rows, tags_to_rows2, 'Inconsistent rows_to_tags');
  }

  // get tag for an row, '' if it doesn't exist
  public async getTags(row: Row): Promise<Tags | null> {
    const tags = await this._getRowsToTags();
    return tags[row] || null;
  }

  private async _setTag(row: Row, tag: Tag) {
    await this._sanityCheckTags();
    const tags_to_rows = await this._getTagsToRows();
    const rows_to_tags = await this._getRowsToTags();
    errors.assert(!tags_to_rows.hasOwnProperty(tag) || !tags_to_rows[tag].includes(row));
    errors.assert(!rows_to_tags.hasOwnProperty(row) || !rows_to_tags[row].includes(tag));
    if (!tags_to_rows[tag]) {
      tags_to_rows[tag] = [];
    }
    if (!rows_to_tags[row]) {
      rows_to_tags[row] = [];
    }
    tags_to_rows[tag].push(row);
    rows_to_tags[row].push(tag);
    tags_to_rows[tag].sort();
    rows_to_tags[row].sort();
    await this._setTagsToRows(tags_to_rows);
    await this._setRowsToTags(rows_to_tags);
    await this._sanityCheckTags();
  }

  private async _unsetTag(row: Row, tag: Tag) {
    await this._sanityCheckTags();
    const tags_to_rows = await this._getTagsToRows();
    const rows_to_tags = await this._getRowsToTags();
    errors.assert(tags_to_rows[tag].includes(row));
    errors.assert(rows_to_tags[row].includes(tag));
    tags_to_rows[tag] = tags_to_rows[tag].filter((el) => { return el !== row; });
    rows_to_tags[row] = rows_to_tags[row].filter((el) => { return el !== tag; });
    if (tags_to_rows[tag].length === 0) {
      delete tags_to_rows[tag];
    }
    if (rows_to_tags[row].length === 0) {
      delete rows_to_tags[row];
    }
    await this._setTagsToRows(tags_to_rows);
    await this._setRowsToTags(rows_to_tags);
    await this._sanityCheckTags();
  }


  public async listTags(): Promise<{[tag: string]: Path[]}> {
    await this._sanityCheckTags();
    const tags_to_rows = await this._getTagsToRows();

    const all_tags: {[tag: string]: Path[]} = {};
    await Promise.all(
      Object.keys(tags_to_rows).map(async (tag) => {
        const rows = tags_to_rows[tag];
        all_tags[tag] = [];
        await Promise.all(
          rows.map(async (row) => {
            const path = await this.document.canonicalPath(row);
            if (path !== null) {
              all_tags[tag].push(path);
            }
          })
        );
      })
    );
    return all_tags;
  }

  // Set the tag for row
  // Returns whether setting tag succeeded
  public async addTag(row: Row, tag: Tag) {
    const tags_to_rows = await this._getTagsToRows();
    // const rows_to_tags = await this._getRowsToTags();

    if (tag in tags_to_rows) {
      if (tags_to_rows[tag].includes(row)) {
        return 'Already tagged, nothing to do!';
      }
    }

    await this.session.do(new this.SetTag(row, tag));

    return null;
  }

  // Delete the tag for row
  // Returns whether removing tag succeeded
  public async removeTag(row: Row, tag: Tag) {
    const rows_to_tags = await this._getRowsToTags();
    const oldtags = rows_to_tags[row];

    if (oldtags === null || !oldtags.includes(tag)) {
        return 'Tag not in row, nothing to do!';
    }

    await this.session.do(new this.UnsetTag(row, tag));

    return null;
  }
  // Set the tag for row

  // Returns whether setting tag succeeded
  public async setTags(row: Row, tags: Tags) {
    const rows_to_tags = await this._getRowsToTags();

    let err = null;

    if (row in rows_to_tags) {
      for (let tag of rows_to_tags[row]) {
        err = await this.removeTag(row, tag);
      }
    }
    if (err) {
      return err;
    }
    for (let tag of tags) {
      err = await this.addTag(row, tag);
    }
    if (err) {
      return err;
    }
    return null;
  }
}


export const pluginName = 'Tags';

registerPlugin<TagsPlugin>(
  {
    name: pluginName,
    author: 'Victor Tao',
    description:
      `Similar to Marks, but each row can have multiple tags and tags can be reused.
      Press '#' to add a new tag, 'd#[number]' to remove a tag, and '-' to search tags.
   `,
    version: 1,
  },
  async (api) => {
    const tagsPlugin = new TagsPlugin(api);
    await tagsPlugin.enable();
    return tagsPlugin;
  },
  (api) => api.deregisterAll(),
);
