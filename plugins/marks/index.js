/* globals virtualDom */
import _ from 'lodash';

import * as Plugins from '../../assets/js/plugins';
import Menu from '../../assets/js/menu';
import * as Modes from '../../assets/js/modes';
import * as DataStore from '../../assets/js/datastore';
import Document from '../../assets/js/document';
import Session from '../../assets/js/session';
import * as Render from '../../assets/js/render';
import Mutation from '../../assets/js/mutations';
import * as errors from '../../assets/js/errors';
import * as constants from '../../assets/js/constants';

import * as basic_defs from '../../assets/js/definitions/basics';

import './marks.sass';

// NOTE: mark mode is still in the core code
// TODO: separate that out too?

class MarksPlugin {
  constructor(api) {
    this.api = api;
    this.enableAPI();
  }

  enableAPI() {
    this.logger = this.api.logger;
    this.session = this.api.session;
    this.document = this.session.document;
    const that = this;

    class SetMark extends Mutation {
      constructor(row, mark) {
        super();
        this.row = row;
        this.mark = mark;
      }
      str() {
        return `row ${this.row}, mark ${this.mark}`;
      }
      mutate(/* session */) {
        return that._setMark(this.row, this.mark);
      }
      rewind(/* session */) {
        return [
          /* eslint-disable no-use-before-define */
          new UnsetMark(this.row)
          /* eslint-enable no-use-before-define */
        ];
      }
    }
    this.SetMark = SetMark;

    class UnsetMark extends Mutation {
      constructor(row) {
        super();
        this.row = row;
      }
      str() {
        return `row ${this.row}`;
      }
      mutate(/* session */) {
        this.mark = that._getMark(this.row);
        return that._unsetMark(this.row, this.mark);
      }
      rewind(/* session */) {
        return [
          new SetMark(this.row, this.mark)
        ];
      }
    }
    this.UnsetMark = UnsetMark;

    // Serialization #

    this.api.registerHook('document', 'serializeRow', (struct, info) => {
      const mark = this._getMark(info.row);
      if (mark) {
        struct.mark = mark;
      }
      return struct;
    });

    this.api.registerListener('document', 'loadRow', async (path, serialized) => {
      if (serialized.mark) {
        const err = await this.updateMark(path.row, serialized.mark);
        if (err) { return this.session.showMessage(err, {text_class: 'error'}); }
      }
    });

    // Commands #

    const MODES = Modes.modes;

    this.marksession = null;
    this.marksessionpath = null;

    this.api.registerMode({
      name: 'MARK',
      hotkey_type: Modes.INSERT_MODE_TYPE,
      within_row: true,
      enter: async (session) => {
        // initialize marks stuff
        const doc = new Document(new DataStore.InMemory());
        doc.load(constants.empty_data);
        this.marksession = new Session(doc);
        await this.marksession.setMode(MODES.INSERT);
        return this.marksessionpath = session.cursor.path;
      },
      exit: async (/*session*/) => {
        this.marksession = null;
        return this.marksessionpath = null;
      },
      key_transforms: [
        (key, context) => {
          // must be non-whitespace
          if (key.length === 1) {
            if (/^\S*$/.test(key)) {
              this.marksession.addCharsAtCursor([{char: key}]);
              return [null, context];
            }
          }
          return [key, context];
        }
      ]
    });

    const CMD_MARK = this.api.registerCommand({
      name: 'MARK',
      default_hotkeys: {
        normal_like: ['m']
      }
    });
    this.api.registerAction([MODES.NORMAL], CMD_MARK, {
      description: 'Mark a line',
    }, async function() {
      return await this.session.setMode(MODES.MARK);
    });

    const CMD_FINISH_MARK = this.api.registerCommand({
      name: 'FINISH_MARK',
      default_hotkeys: {
        insert_like: ['enter']
      }
    });
    this.api.registerAction([MODES.MARK], CMD_FINISH_MARK, {
      description: 'Finish typing mark',
    }, async function() {
      const mark = (that.marksession.curText()).join('');
      const err = await that.updateMark(that.marksessionpath.row, mark);
      if (err) { this.session.showMessage(err, {text_class: 'error'}); }
      await this.session.setMode(MODES.NORMAL);
      return this.keyStream.save();
    });

    const CMD_GO = this.api.commands.GO;
    this.api.registerMotion([CMD_GO, CMD_MARK], {
      description: 'Go to the mark indicated by the cursor, if it exists',
    }, async function() {
      return async cursor => {
        const word = this.session.document.getWord(cursor.row, cursor.col);
        if (word.length < 1 || word[0] !== '@') {
          return false;
        }
        const mark = word.slice(1);
        const allMarks = that.listMarks();
        if (mark in allMarks) {
          const row = allMarks[mark];
          const path = this.session.document.canonicalPath(row);
          await this.session.zoomInto(path);
          return true;
        } else {
          return false;
        }
      };
    });

    const CMD_DELETE = this.api.commands.DELETE;
    this.api.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_MARK], {
      description: 'Delete mark at cursor'
    }, async function() {
      const err = await that.updateMark(this.session.cursor.row, '');
      if (err) { this.session.showMessage(err, {text_class: 'error'}); }
      return this.keyStream.save();
    });

    const CMD_MARK_SEARCH = this.api.registerCommand({
      name: 'MARK_SEARCH',
      default_hotkeys: {
        normal_like: ['\'', '`']
      }
    });
    this.api.registerAction([MODES.NORMAL], CMD_MARK_SEARCH, {
      description: 'Go to (search for) a mark',
    }, async function() {
      await this.session.setMode(MODES.SEARCH);
      return this.session.menu = new Menu(this.session.menuDiv, chars => {
        // find marks that start with the prefix
        const findMarks = (document, prefix, nresults = 10) => {
          const marks = that.listMarks();
          const results = []; // list of paths
          for (const mark in marks) {
            const row = marks[mark];
            if ((mark.indexOf(prefix)) === 0) {
              const path = this.session.document.canonicalPath(row);
              results.push({ path, mark });
              if (nresults > 0 && results.length === nresults) {
                break;
              }
            }
          }
          return results;
        };

        const text = chars.join('');
        return _.map(
          (findMarks(this.session.document, text)),
          found => {
            const path = found.path;
            return {
              contents: this.session.document.getLine(path.row),
              renderHook(contents) {
                contents.unshift(virtualDom.h('span', {
                  className: 'mark theme-bg-secondary theme-trim'
                }, found.mark)
                );
                return contents;
              },
              fn: async () => await this.session.zoomInto(path)
            };
          }
        );
      });
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_MOTION, {
      description: 'Move the cursor',
    }, async function(motion) {
      return motion(that.marksession.cursor, {pastEnd: true});
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_DELETE_LAST_CHAR, {
      description: 'Delete last character (i.e. backspace key)',
    }, async function() {
      return await that.marksession.deleteAtCursor();
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_DELETE_CHAR, {
      description: 'Delete character at the cursor (i.e. del key)',
    }, async function() {
      return this.session.sarkvession.delCharsAfterCursor(1);
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_HELP, {
      description: 'Show/hide key bindings (edit in settings)',
    }, async function() {
      this.session.toggleBindingsDiv();
      return this.keyStream.forget(1);
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_EXIT_MODE, {
      description: 'Exit back to normal mode',
    }, async function() {
      await this.session.setMode(MODES.NORMAL);
      return this.keyStream.forget();
    });

    this.api.registerHook('session', 'renderCursorsDict', (cursors, info) => {
      const marking = (this.marksessionpath !== null) && this.marksessionpath.is(info.path);
      if (marking) {
        return {}; // do not render any cursors on the regular line
      }
      return cursors;
    });

    this.api.registerHook('session', 'renderLineContents', (lineContents, info) => {
      const marking = (this.marksessionpath !== null) && this.marksessionpath.is(info.path);
      if (marking) {
        const markresults = Render.virtualRenderLine(this.marksession, this.marksession.cursor.path, {no_clicks: true});
        lineContents.unshift(virtualDom.h('span', {
          className: 'mark theme-bg-secondary theme-trim-accent'
        }, markresults));
      } else {
        const mark = this._getMark(info.path.row);
        if (mark) {
          lineContents.unshift(virtualDom.h('span', {
            className: 'mark theme-bg-secondary theme-trim'
          }, mark));
        }
      }
      return lineContents;
    });

    return this.api.registerHook('session', 'renderLineWordHook', (line, word_info) => {
      if (this.session.mode === MODES.NORMAL) {
        if (word_info.word[0] === '@') {
          const mark = word_info.word.slice(1);
          const row = this.getRowForMark(mark);
          if (row !== null) {
            const markpath = this.document.canonicalPath(row);
            errors.assert((markpath !== null));
            for (let i = word_info.start; i <= word_info.end; i++) {
              line[i].renderOptions.type = 'a';
              line[i].renderOptions.onclick = async () => {
                await this.session.zoomInto(markpath);
                this.session.save();
                this.session.render();
              };
            }
          }
        }
      }
      return line;
    });
  }

  // maintain global marks data structures
  //   a map: row -> mark
  //   and a second map: mark -> row
  _getRowsToMarks() {
    return this.api.getData('ids_to_marks', {});
  }
  _setRowsToMarks(rows_to_marks) {
    return this.api.setData('ids_to_marks', rows_to_marks);
  }
  _getMarksToRows() {
    return this.api.getData('marks_to_ids', {});
  }
  _setMarksToRows(mark_to_rows) {
    return this.api.setData('marks_to_ids', mark_to_rows);
  }

  _sanityCheckMarks() {
    const marks_to_rows = this._getMarksToRows();
    const rows_to_marks = this._getRowsToMarks();
    const marks_to_rows2 = {};
    for (const row in rows_to_marks) {
      const mark = rows_to_marks[row];
      marks_to_rows2[mark] = parseInt(row);
    }
    return errors.assert_deep_equals(marks_to_rows, marks_to_rows2, 'Inconsistent rows_to_marks');
  }

  // get mark for an row, '' if it doesn't exist
  _getMark(row) {
    const marks = this._getRowsToMarks();
    return marks[row] || '';
  }

  _setMark(row, mark) {
    this._sanityCheckMarks();
    const marks_to_rows = this._getMarksToRows();
    const rows_to_marks = this._getRowsToMarks();
    errors.assert(!marks_to_rows.hasOwnProperty(mark));
    errors.assert(!rows_to_marks.hasOwnProperty(row));
    marks_to_rows[mark] = row;
    rows_to_marks[row] = mark;
    this._setMarksToRows(marks_to_rows);
    this._setRowsToMarks(rows_to_marks);
    return this._sanityCheckMarks();
  }

  _unsetMark(row, mark) {
    this._sanityCheckMarks();
    const marks_to_rows = this._getMarksToRows();
    const rows_to_marks = this._getRowsToMarks();
    errors.assert_equals(marks_to_rows[mark], row);
    errors.assert_equals(rows_to_marks[row], mark);
    delete marks_to_rows[mark];
    delete rows_to_marks[row];
    this._setMarksToRows(marks_to_rows);
    this._setRowsToMarks(rows_to_marks);
    return this._sanityCheckMarks();
  }

  getRowForMark(mark) {
    this._sanityCheckMarks();
    const marks_to_rows = this._getMarksToRows();
    if (!(mark in marks_to_rows)) {
      return null;
    }
    const row = marks_to_rows[mark];
    if (this.document.isAttached(row)) {
      return row;
    }
    return null;
  }

  listMarks() {
    this._sanityCheckMarks();
    const marks_to_rows = this._getMarksToRows();

    const all_marks = {};
    for (const mark in marks_to_rows) {
      const row = marks_to_rows[mark];
      if (this.document.isAttached(row)) {
        all_marks[mark] = row;
      }
    }
    return all_marks;
  }

  // Set the mark for row
  // Returns whether setting mark succeeded
  async updateMark(row, mark = '') {
    const marks_to_rows = this._getMarksToRows();
    const rows_to_marks = this._getRowsToMarks();
    const oldmark = rows_to_marks[row];

    if (!(oldmark || mark)) {
      return 'No mark to delete!';
    }

    if (mark in marks_to_rows) {
      if (marks_to_rows[mark] === row) {
        return 'Already marked, nothing to do!';
      }

      const other_row = marks_to_rows[mark];
      if (this.document.isAttached(other_row)) {
        return `Mark '${mark}' was already taken!`;
      } else {
        await this.session.do(new this.UnsetMark(other_row, mark));
      }
    }

    if (oldmark) {
      await this.session.do(new this.UnsetMark(row, oldmark));
    }

    if (mark) {
      await this.session.do(new this.SetMark(row, mark));
    }

    return null;
  }
}

// NOTE: because listing marks filters, disabling is okay

const pluginName = 'Marks';

Plugins.register({
  name: pluginName,
  author: 'Jeff Wu',
  description:
    `Lets you tag a row with a string, and then reference that row with @markname.
Fast search for marked rows, using '.`
}, (api => new MarksPlugin(api)), (api => api.deregisterAll())
);

export { pluginName };
