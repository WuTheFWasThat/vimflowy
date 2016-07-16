import _ from 'lodash';

import Plugins from '../../assets/js/plugins';
import Menu from '../../assets/js/menu';
import Modes from '../../assets/js/modes';
import DataStore from '../../assets/js/datastore';
import Document from '../../assets/js/document';
import Session from '../../assets/js/session';
import Render from '../../assets/js/render';
import mutations from '../../assets/js/mutations';
import errors from '../../assets/js/errors';

import basic_defs from '../../assets/js/definitions/basics';

// NOTE: mark mode is still in the core code
// TODO: separate that out too?

class MarksPlugin {
  constructor(api) {
    this.goMark = this.goMark.bind(this);
    this.api = api;
    this.enableAPI();
  }

  enableAPI() {
    this.logger = this.api.logger;
    this.session = this.api.session;
    this.document = this.session.document;
    let that = this;

    class SetMark extends mutations.Mutation {
      constructor(row, mark) {
        this.row = row;
        this.mark = mark;
      }
      str() {
        return `row ${this.row}, mark ${this.mark}`;
      }
      mutate(session) {
        return that._setMark(this.row, this.mark);
      }
      rewind(session) {
        return [
          new UnsetMark(this.row)
        ];
      }
    }
    this.SetMark = SetMark;

    class UnsetMark extends mutations.Mutation {
      constructor(row) {
        this.row = row;
      }
      str() {
        return `row ${this.row}`;
      }
      mutate(session) {
        this.mark = that._getMark(this.row);
        return that._unsetMark(this.row, this.mark);
      }
      rewind(session) {
        return [
          new SetMark(this.row, this.mark)
        ];
      }
    }
    this.UnsetMark = UnsetMark;

    // Serialization #

    this.api.registerHook('document', 'serializeRow', (struct, info) => {
      let mark = this._getMark(info.row);
      if (mark) {
        struct.mark = mark;
      }
      return struct;
    }
    );

    this.api.registerListener('document', 'loadRow', (path, serialized) => {
      if (serialized.mark) {
        let err = this.updateMark(path.row, serialized.mark);
        if (err) { return this.session.showMessage(err, {text_class: 'error'}); }
      }
    }
    );

    // Commands #

    let MODES = Modes.modes;

    this.marksession = null;
    this.marksessionpath = null;

    this.api.registerMode({
      name: 'MARK',
      hotkey_type: Modes.INSERT_MODE_TYPE,
      within_row: true,
      enter: session => {
        // initialize marks stuff
        let document = new Document((new DataStore.InMemory()));
        this.marksession = new Session(document);
        this.marksession.setMode(MODES.INSERT);
        return this.marksessionpath = session.cursor.path;
      },
      exit: session => {
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
    }
    );

    let CMD_MARK = this.api.registerCommand({
      name: 'MARK',
      default_hotkeys: {
        normal_like: ['m']
      }
    }
    );
    this.api.registerAction([MODES.NORMAL], CMD_MARK, {
      description: 'Mark a line',
    }, function() {
      return this.session.setMode(MODES.MARK);
    }
    );

    let CMD_FINISH_MARK = this.api.registerCommand({
      name: 'FINISH_MARK',
      default_hotkeys: {
        insert_like: ['enter']
      }
    }
    );
    this.api.registerAction([MODES.MARK], CMD_FINISH_MARK, {
      description: 'Finish typing mark',
    }, function() {
      let mark = (that.marksession.curText()).join('');
      let err = that.updateMark(that.marksessionpath.row, mark);
      if (err) { this.session.showMessage(err, {text_class: 'error'}); }
      this.session.setMode(MODES.NORMAL);
      return this.keyStream.save();
    }
    );

    let CMD_GO = this.api.commands.GO;
    this.api.registerMotion([CMD_GO, CMD_MARK], {
      description: 'Go to the mark indicated by the cursor, if it exists',
    },  () =>
      cursor => {
        let word = this.session.document.getWord(cursor.row, cursor.col);
        if (word.length < 1 || word[0] !== '@') {
          return false;
        }
        let mark = word.slice(1);
        let allMarks = that.listMarks();
        if (mark in allMarks) {
          let row = allMarks[mark];
          let path = this.session.document.canonicalPath(row);
          this.session.zoomInto(path);
          return true;
        } else {
          return false;
        }
      }
    
    );

    let CMD_DELETE = this.api.commands.DELETE;
    this.api.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_MARK], {
      description: 'Delete mark at cursor'
    }, function() {
      let err = (that.updateMark(this.session.cursor.row, ''));
      if (err) { this.session.showMessage(err, {text_class: 'error'}); }
      return this.keyStream.save();
    }
    );

    let CMD_MARK_SEARCH = this.api.registerCommand({
      name: 'MARK_SEARCH',
      default_hotkeys: {
        normal_like: ['\'', '`']
      }
    }
    );
    this.api.registerAction([MODES.NORMAL], CMD_MARK_SEARCH, {
      description: 'Go to (search for) a mark',
    }, function() {
      this.session.setMode(MODES.SEARCH);
      return this.session.menu = new Menu(this.session.menuDiv, chars => {
        // find marks that start with the prefix
        let findMarks = (document, prefix, nresults = 10) => {
          let iterable;
          let results = []; // list of paths
          for (let mark in ((iterable = that.listMarks()))) {
            let row = iterable[mark];
            if ((mark.indexOf(prefix)) === 0) {
              let path = this.session.document.canonicalPath(row);
              results.push({ path, mark });
              if (nresults > 0 && results.length === nresults) {
                break;
              }
            }
          }
          return results;
        };

        let text = chars.join('');
        return _.map(
          (findMarks(this.session.document, text)),
          found => {
            let { path } = found;
            return {
              contents: this.session.document.getLine(path.row),
              renderHook(contents) {
                contents.unshift(virtualDom.h('span', {
                  className: 'mark theme-bg-secondary theme-trim'
                }, found.mark)
                );
                return contents;
              },
              fn: () => this.session.zoomInto(path)
            };
          }
        );
      }
      );
    }
    );

    this.api.registerAction([MODES.MARK], basic_defs.CMD_MOTION, {
      description: 'Move the cursor',
    }, motion => motion(that.marksession.cursor, {pastEnd: true})
    );

    this.api.registerAction([MODES.MARK], basic_defs.CMD_DELETE_LAST_CHAR, {
      description: 'Delete last character (i.e. backspace key)',
    }, () => that.marksession.deleteAtCursor()
    );

    this.api.registerAction([MODES.MARK], basic_defs.CMD_DELETE_CHAR, {
      description: 'Delete character at the cursor (i.e. del key)',
    }, function() {
      return this.session.sarkvession.delCharsAfterCursor(1);
    }
    );

    this.api.registerAction([MODES.MARK], basic_defs.CMD_HELP, {
      description: 'Show/hide key bindings (edit in settings)',
    }, function() {
      this.session.toggleBindingsDiv();
      return this.keyStream.forget(1);
    }
    );

    this.api.registerAction([MODES.MARK], basic_defs.CMD_EXIT_MODE, {
      description: 'Exit back to normal mode',
    }, function() {
      this.session.setMode(MODES.NORMAL);
      return this.keyStream.forget();
    }
    );

    this.api.registerHook('session', 'renderCursorsDict', (cursors, info) => {
      let marking = (this.marksessionpath != null) && this.marksessionpath.is(info.path);
      if (marking) {
        return {}; // do not render any cursors on the regular line
      }
      return cursors;
    }
    );

    this.api.registerHook('session', 'renderLineContents', (lineContents, info) => {
      let marking = (this.marksessionpath != null) && this.marksessionpath.is(info.path);
      if (marking) {
        let markresults = Render.virtualRenderLine(this.marksession, this.marksession.cursor.path, {no_clicks: true});
        lineContents.unshift(virtualDom.h('span', {
          className: 'mark theme-bg-secondary theme-trim-accent'
        }, markresults)
        );
      } else {
        let mark = this._getMark(info.path.row);
        if (mark) {
          lineContents.unshift(virtualDom.h('span', {
            className: 'mark theme-bg-secondary theme-trim'
          }, mark));
        }
      }
      return lineContents;
    }
    );

    return this.api.registerHook('session', 'renderLineWordHook', (line, word_info) => {
      if (this.session.mode === MODES.NORMAL) {
        if (word_info.word[0] === '@') {
          let mark = word_info.word.slice(1);
          let row = this.getRowForMark(mark);
          if (row !== null) {
            let markpath = this.document.canonicalPath(row);
            errors.assert((markpath !== null));
            let iterable = __range__(word_info.start, word_info.end, true);
            for (let j = 0; j < iterable.length; j++) {
              let i = iterable[j];
              line[i].renderOptions.type = 'a';
              line[i].renderOptions.onclick = this.goMark.bind(this, markpath);
            }
          }
        }
      }
      return line;
    }
    );
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
    let marks_to_rows = this._getMarksToRows();
    let rows_to_marks = this._getRowsToMarks();
    let marks_to_rows2 = {};
    for (let row in rows_to_marks) {
      let mark = rows_to_marks[row];
      marks_to_rows2[mark] = parseInt(row);
    }
    return errors.assert_deep_equals(marks_to_rows, marks_to_rows2, "Inconsistent rows_to_marks");
  }

  // get mark for an row, '' if it doesn't exist
  _getMark(row) {
    let marks = this._getRowsToMarks();
    return marks[row] || '';
  }

  _setMark(row, mark) {
    this._sanityCheckMarks();
    let marks_to_rows = this._getMarksToRows();
    let rows_to_marks = this._getRowsToMarks();
    errors.assert(!(__in__(mark, marks_to_rows)));
    errors.assert(!(__in__(row, rows_to_marks)));
    marks_to_rows[mark] = row;
    rows_to_marks[row] = mark;
    this._setMarksToRows(marks_to_rows);
    this._setRowsToMarks(rows_to_marks);
    return this._sanityCheckMarks();
  }

  _unsetMark(row, mark) {
    this._sanityCheckMarks();
    let marks_to_rows = this._getMarksToRows();
    let rows_to_marks = this._getRowsToMarks();
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
    let marks_to_rows = this._getMarksToRows();
    if (!(mark in marks_to_rows)) {
      return null;
    }
    let row = marks_to_rows[mark];
    if (this.document.isAttached(row)) {
      return row;
    }
    return null;
  }

  listMarks() {
    this._sanityCheckMarks();
    let marks_to_rows = this._getMarksToRows();

    let all_marks = {};
    for (let mark in marks_to_rows) {
      let row = marks_to_rows[mark];
      if (this.document.isAttached(row)) {
        all_marks[mark] = row;
      }
    }
    return all_marks;
  }

  // Set the mark for row
  // Returns whether setting mark succeeded
  updateMark(row, mark = '') {
    let marks_to_rows = this._getMarksToRows();
    let rows_to_marks = this._getRowsToMarks();
    let oldmark = rows_to_marks[row];

    if (!(oldmark || mark)) {
      return "No mark to delete!";
    }

    if (mark in marks_to_rows) {
      if (marks_to_rows[mark] === row) {
        return "Already marked, nothing to do!";
      }

      let other_row = marks_to_rows[mark];
      if (this.document.isAttached(other_row)) {
        return `Mark '${mark}' was already taken!`;
      } else {
        this.session.do(new this.UnsetMark(other_row, mark));
      }
    }

    if (oldmark) {
      this.session.do(new this.UnsetMark(row, oldmark));
    }

    if (mark) {
      this.session.do(new this.SetMark(row, mark));
    }

    return null;
  }

  goMark(path) {
    this.session.zoomInto(path);
    this.session.save();
    return this.session.render();
  }
}

// NOTE: because listing marks filters, disabling is okay

let pluginName = "Marks";

Plugins.register({
  name: pluginName,
  author: "Jeff Wu",
  description:
    `Lets you tag a row with a string, and then reference that row with @markname.
Fast search for marked rows, using '.`
}, (api => new MarksPlugin(api)), (api => api.deregisterAll())
);
export { pluginName };

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}
function __in__(needle, haystack) {
  return haystack.indexOf(needle) >= 0;
}