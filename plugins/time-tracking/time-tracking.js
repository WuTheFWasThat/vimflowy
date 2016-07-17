// Time-tracking keeps track of the amount of time spent in each subtree.
// Clones are double-counted. This is a known bug and will not be fixed.
//
import Plugins from '../../assets/js/plugins';
import Modes from '../../assets/js/modes';

Plugins.register({
  name: "Time Tracking",
  author: "Zachary Vance",
  description: "Keeps track of how much time has been spent in each row (including its descendants)",
  version: 3
}, (function(api) {
  let time_tracker;
  return time_tracker = new TimeTrackingPlugin(api);
}), (api => api.deregisterAll())
);

class TimeTrackingPlugin {
  constructor(api) {
    this.api = api;
    this.enableAPI();
  }

  enableAPI() {
    this.logger = this.api.logger;
    this.logger.info("Loading time tracking");
    this.api.cursor.on('rowChange', (this.onRowChange.bind(this)));
    this.currentRow = null;
    this.onRowChange(null, this.api.cursor.path); // Initial setup

    this.api.registerHook('session', 'renderInfoElements', (elements, renderData) => {
      let time = this.rowTime(renderData.path);

      let isCurRow = renderData.path.row === (this.currentRow && this.currentRow.row);

      if (isCurRow || time > 1000) {
        let timeStr = " ";
        timeStr += (this.printTime(time));
        if (isCurRow) {
          timeStr += " + ";
        }
        elements.push(virtualDom.h('span', { className: 'time' }, timeStr));

        if (isCurRow) {
          let curTime = new Date() - this.currentRow.time;
          elements.push(virtualDom.h('span', { className: 'time curtime' }, (this.printTime(curTime))));
        }
      }
      return elements;
    }
    );

    this.api.registerListener('document', 'afterMove', info => {
      this._rebuildTreeTime(info.id);
      return this._rebuildTreeTime(info.old_parent, true);
    }
    );

    this.api.registerListener('document', 'afterAttach', info => {
      this._rebuildTreeTime(info.id);
      if (info.old_detached_parent) {
        return this._rebuildTreeTime(info.old_detached_parent, true);
      }
    }
    );

    this.api.registerListener('document', 'afterDetach', info => {
      return this._rebuildTreeTime(info.id);
    }
    );

    this.api.registerListener('session', 'exit', () => {
      return this.onRowChange(this.currentRow, null);
    }
    );

    let CMD_TOGGLE = this.api.registerCommand({
      name: 'TOGGLE',
      default_hotkeys: {
        normal_like: ['Z']
      }
    }
    );
    let CMD_TOGGLE_LOGGING = this.api.registerCommand({
      name: 'TOGGLE_LOGGING',
      default_hotkeys: {
        normal_like: ['l']
      }
    }
    );
    let CMD_CLEAR_TIME = this.api.registerCommand({
      name: 'CLEAR_TIME',
      default_hotkeys: {
        normal_like: ['c']
      }
    }
    );
    let CMD_ADD_TIME = this.api.registerCommand({
      name: 'ADD_TIME',
      default_hotkeys: {
        normal_like: ['>', 'a']
      }
    }
    );
    let CMD_SUBTRACT_TIME = this.api.registerCommand({
      name: 'SUBTRACT_TIME',
      default_hotkeys: {
        normal_like: ['<', 's']
      }
    }
    );
    this.api.registerAction([Modes.modes.NORMAL], CMD_TOGGLE, {
      description: 'Toggle a setting',
    }, {});
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_LOGGING], {
      description: 'Toggle whether time is being logged',
    }, () => {
      return this.toggleLogging();
    }
    );
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_CLEAR_TIME], {
      description: 'Clear current row time',
    }, () => {
      return this.resetCurrentRow();
    }
    );
    let me = this;
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_ADD_TIME], {
      description: 'Add time to current row (in minutes)',
    }, function() {
      return me.changeTimeCurrentRow(this.repeat);
    }
    );
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_SUBTRACT_TIME], {
      description: 'Subtract time from current row (in minutes)',
    }, function() {
      return me.changeTimeCurrentRow(-this.repeat);
    }
    );

    return setInterval((() => {
      if (this.currentRow != null) {
        let curTime = new Date() - this.currentRow.time;
        return $('.curtime').text((this.printTime(curTime)));
      }
    }
    ), 1000);
  }

  changeTimeCurrentRow(delta_minutes) {
    if (this.currentRow != null) {
      let curTime = new Date() - this.currentRow.time;
      curTime += delta_minutes * 60 * 1000;
      if (curTime < 0) {
        this.currentRow.time = new Date();
        return this.modifyTimeForId(this.currentRow.row, curTime);
      } else {
        return this.currentRow.time = new Date() - curTime;
      }
    }
  }

  getRowData(id, keytype, default_value=null) {
    let key = `${id}:${keytype}`;
    return this.api.getData(key, default_value);
  }

  setRowData(id, keytype, value) {
    let key = `${id}:${keytype}`;
    return this.api.setData(key, value);
  }

  transformRowData(id, keytype, transform) {
    return this.setRowData(id, keytype, (transform((this.getRowData(id, keytype)))));
  }

  isLogging() {
    return this.api.getData("isLogging", true);
  }

  toggleLogging() {
    let isLogging = this.isLogging();
    if (isLogging) {
      this.logger.info('Turning logging off');
      this.onRowChange(this.api.cursor.row, null); // Final close
      return this.api.setData('isLogging', false);
    } else {
      this.logger.info('Turning logging on');
      this.api.setData('isLogging', true);
      return this.onRowChange(null, this.api.cursor.row); // Initial setup
    }
  }

  onRowChange(from, to) {
    this.logger.debug(`Switching from row ${from && from.row} to row ${to && to.row}`);
    if (!this.isLogging()) {
      return;
    }
    let time = new Date();
    if (this.currentRow && this.currentRow.row !== (to && to.row)) {
      this.modifyTimeForId(from.row, (time - this.currentRow.time));
      this.currentRow = null;
    }
    if (to != null) {
      return this.currentRow != null ? this.currentRow : (this.currentRow = { id: to.row, time });
    }
  }

  resetCurrentRow() {
    if (this.currentRow) {
      return this.currentRow.time = new Date();
    }
  }

  modifyTimeForId(id, delta) {
    this.transformRowData(id, "rowTotalTime", current => (current || 0) + delta
    );
    return this._rebuildTreeTime(id, true);
  }

  _rebuildTotalTime(id) {
    let children = this.api.session.document._getChildren(id);
    let detached_children = this.api.session.document.store.getDetachedChildren(id);

    let childTotalTimes = _.map(children.concat(detached_children), child_id => this.getRowData(child_id, "treeTotalTime", 0));
    let rowTime = this.getRowData(id, "rowTotalTime", 0);
    let totalTime = childTotalTimes.reduce(((a,b) => a+b), rowTime);
    return this.setRowData(id, "treeTotalTime", totalTime);
  }

  _rebuildTreeTime(id, inclusive = false) {
    let iterable = this.api.session.document.allAncestors(id, { inclusive });
    for (let i = 0; i < iterable.length; i++) {
      let ancestor_id = iterable[i];
      this._rebuildTotalTime(ancestor_id);
    }
    return null;
  }

  rowTime(row) {
    return this.getRowData(row.row, "treeTotalTime", 0);
  }

  pad(val, length, padChar = '0') {
    val += '';
    let numPads = length - val.length;
    if (numPads > 0) { return new Array(numPads + 1).join(padChar) + val; } else { return val; }
  }

  printTime(ms) {
    let sign = "";
    if (ms < 0) {
      sign = "-";
      ms = - ms;
    }
    let seconds = Math.floor(((ms /     1000) % 60));
    let minutes = Math.floor(((ms /    60000) % 60));
    let hours   = Math.floor((ms /  3600000));
    if (hours > 0) {
      return `${sign}${hours}h:${pad(minutes, 2)}m`;
    } else if (minutes > 0) {
      return `${sign}${minutes}m:${pad(seconds, 2)}s`;
    } else {
      return `${sign}${seconds}s`;
    }
  }
}

