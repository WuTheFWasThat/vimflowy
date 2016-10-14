// Time-tracking keeps track of the amount of time spent in each subtree.
// Clones are double-counted. This is a known bug and will not be fixed.

import $ from 'jquery';
import React from 'react';

import * as Plugins from '../../assets/js/plugins';
import * as Modes from '../../assets/js/modes';

function pad(val, length, padChar = '0') {
  val += '';
  let numPads = length - val.length;
  if (numPads === 0) { return val; }
  return new Array(numPads + 1).join(padChar) + val;
}

class TimeTrackingPlugin {
  constructor(api) {
    this.api = api;
    this.enableAPI();
  }

  enableAPI() {
    this.logger = this.api.logger;
    this.logger.info('Loading time tracking');
    this.currentRow = null;

    // TODO: sequence onRowChange?
    this.onRowChange(null, this.api.cursor.path); // Initial setup, fire and forget
    // NOTE: all these are fire and forget
    this.api.cursor.on('rowChange', this.onRowChange.bind(this));

    this.api.registerHook('document', 'pluginPathContents', async (obj, { path }) => {
      obj.timeTracked = await this.rowTime(path);
      return obj;
    });

    this.api.registerHook('document', 'pluginPathContentsSync', (obj, { path }) => {
      obj.timeTracked = this.rowTimeSync(path);
      return obj;
    });

    this.api.registerHook('session', 'renderAfterLine', (elements, renderData) => {
      const { path, pluginData } = renderData;
      const time = pluginData.timeTracked;
      if (time === null) {
        elements.push(
          <span key='time' style={{color: 'lightgray'}}>Loading...</span>
        );
      } else {
        let isCurRow = path.row === (this.currentRow && this.currentRow.row);

        if (isCurRow || time > 1000) {
          let timeStr = ' ';
          timeStr += (this.printTime(time));
          if (isCurRow) {
            timeStr += ' + ';
          }
          elements.push(
            <span key='time' style={{color: 'lightgray'}}>{timeStr}</span>
          );

          if (isCurRow) {
            let curTime = new Date() - this.currentRow.time;
            elements.push(
              <span key='curtime' style={{color: 'lightgray'}} className='curtime'>
                {this.printTime(curTime)}
              </span>
            );
          }
        }
      }
      return elements;
    });

    this.api.registerListener('document', 'afterMove', async (info) => {
      await this._rebuildTreeTime(info.id);
      await this._rebuildTreeTime(info.old_parent, true);
    });

    this.api.registerListener('document', 'afterAttach', async (info) => {
      await this._rebuildTreeTime(info.id);
      if (info.old_detached_parent) {
        await this._rebuildTreeTime(info.old_detached_parent, true);
      }
    });

    this.api.registerListener('document', 'afterDetach', async (info) => {
      await this._rebuildTreeTime(info.id);
    });

    this.api.registerListener('session', 'exit', async () => {
      await this.onRowChange(this.currentRow, null);
    });

    let CMD_TOGGLE = this.api.registerCommand({
      name: 'TOGGLE',
      default_hotkeys: {
        normal_like: ['Z']
      }
    });
    let CMD_TOGGLE_LOGGING = this.api.registerCommand({
      name: 'TOGGLE_LOGGING',
      default_hotkeys: {
        normal_like: ['l']
      }
    });
    let CMD_CLEAR_TIME = this.api.registerCommand({
      name: 'CLEAR_TIME',
      default_hotkeys: {
        normal_like: ['c']
      }
    });
    let CMD_ADD_TIME = this.api.registerCommand({
      name: 'ADD_TIME',
      default_hotkeys: {
        normal_like: ['>', 'a']
      }
    });
    let CMD_SUBTRACT_TIME = this.api.registerCommand({
      name: 'SUBTRACT_TIME',
      default_hotkeys: {
        normal_like: ['<', 's']
      }
    });
    this.api.registerAction([Modes.modes.NORMAL], CMD_TOGGLE, {
      description: 'Toggle a setting',
    }, {});
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_LOGGING], {
      description: 'Toggle whether time is being logged',
    }, async () => {
      return await this.toggleLogging();
    });
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_CLEAR_TIME], {
      description: 'Clear current row time',
    }, async () => {
      return await this.resetCurrentRow();
    });
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_ADD_TIME], {
      description: 'Add time to current row (in minutes)',
    }, async () => {
      return await this.changeTimeCurrentRow(this.repeat);
    });
    this.api.registerAction([Modes.modes.NORMAL], [CMD_TOGGLE, CMD_SUBTRACT_TIME], {
      description: 'Subtract time from current row (in minutes)',
    }, async () => {
      return await this.changeTimeCurrentRow(-this.repeat);
    });

    return setInterval(() => {
      if (this.currentRow !== null) {
        let curTime = new Date() - this.currentRow.time;
        return $('.curtime').text(this.printTime(curTime));
      }
    }, 1000);
  }

  async changeTimeCurrentRow(delta_minutes) {
    if (this.currentRow !== null) {
      let curTime = new Date() - this.currentRow.time;
      curTime += delta_minutes * 60 * 1000;
      if (curTime < 0) {
        this.currentRow.time = new Date();
        await this.modifyTimeForId(this.currentRow.row, curTime);
      } else {
        this.currentRow.time = new Date() - curTime;
      }
    }
  }

  async getRowData(id, keytype, default_value=null) {
    let key = `${id}:${keytype}`;
    return await this.api.getData(key, default_value);
  }

  getRowDataSync(id, keytype) {
    let key = `${id}:${keytype}`;
    return this.api.getDataSync(key);
  }

  async setRowData(id, keytype, value) {
    let key = `${id}:${keytype}`;
    await this.api.setData(key, value);
  }

  async transformRowData(id, keytype, transform) {
    await this.setRowData(id, keytype, transform(await this.getRowData(id, keytype)));
  }

  async isLogging() {
    return await this.api.getData('isLogging', true);
  }

  async toggleLogging() {
    let isLogging = await this.isLogging();
    if (isLogging) {
      this.logger.info('Turning logging off');
      await this.onRowChange(this.api.cursor.row, null); // Final close
      await this.api.setData('isLogging', false);
    } else {
      this.logger.info('Turning logging on');
      await this.api.setData('isLogging', true);
      await this.onRowChange(null, this.api.cursor.row); // Initial setup
    }
  }

  async onRowChange(from, to) {
    this.logger.debug(`Switching from row ${from && from.row} to row ${to && to.row}`);
    if (!(await this.isLogging())) {
      return;
    }
    let time = new Date();
    if (this.currentRow && this.currentRow.row !== (to && to.row)) {
      await this.modifyTimeForId(from.row, (time - this.currentRow.time));
      this.currentRow = null;
    }
    if (to !== null) {
      return this.currentRow !== null ? this.currentRow : (this.currentRow = { id: to.row, time });
    }
  }

  async resetCurrentRow() {
    if (this.currentRow) {
      this.currentRow.time = new Date();
    }
  }

  async modifyTimeForId(id, delta) {
    await this.transformRowData(id, 'rowTotalTime', current => (current || 0) + delta);
    await this._rebuildTreeTime(id, true);
  }

  async _rebuildTotalTime(id) {
    let children = await this.api.session.document._getChildren(id);
    let detached_children = await this.api.session.document.store.getDetachedChildren(id);

    let childTotalTimes = await Promise.all(
      children.concat(detached_children).map(
        async (child_id) => {
          return await this.getRowData(child_id, 'treeTotalTime', 0);
        }
      )
    );
    let rowTime = await this.getRowData(id, 'rowTotalTime', 0);
    let totalTime = childTotalTimes.reduce((a,b) => a+b, rowTime);
    await this.setRowData(id, 'treeTotalTime', totalTime);
  }

  async _rebuildTreeTime(id, inclusive = false) {
    const ancestors = await this.api.session.document.allAncestors(id, { inclusive });
    for (let i = 0; i < ancestors.length; i++) {
      const ancestor_id = ancestors[i];
      await this._rebuildTotalTime(ancestor_id);
    }
  }

  async rowTime(row) {
    return await this.getRowData(row.row, 'treeTotalTime', 0);
  }

  rowTimeSync(row) {
    return this.getRowDataSync(row.row, 'treeTotalTime');
  }

  printTime(ms) {
    let sign = '';
    if (ms < 0) {
      sign = '-';
      ms = - ms;
    }
    let seconds = Math.floor((ms /     1000) % 60);
    let minutes = Math.floor((ms /    60000) % 60);
    let hours   = Math.floor( ms /  3600000);
    if (hours > 0) {
      return `${sign}${hours}h:${pad(minutes, 2)}m`;
    } else if (minutes > 0) {
      return `${sign}${minutes}m:${pad(seconds, 2)}s`;
    } else {
      return `${sign}${seconds}s`;
    }
  }
}

Plugins.register(
  {
    name: 'Time Tracking',
    author: 'Zachary Vance',
    description: 'Keeps track of how much time has been spent in each row (including its descendants)',
    version: 3
  },
  async (api) => {
    return new TimeTrackingPlugin(api);
  },
  (api => api.deregisterAll())
);

