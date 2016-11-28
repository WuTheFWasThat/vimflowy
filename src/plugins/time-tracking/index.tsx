// Time-tracking keeps track of the amount of time spent in each subtree.
// Clones are double-counted. This is a known bug and will not be fixed.

import $ from 'jquery';
import React from 'react'; // tslint:disable-line no-unused-variable

import * as Plugins from '../../assets/js/plugins';
import { Logger } from '../../assets/js/logger';
import { Row } from '../../assets/js/types';

function pad(val, length, padChar = '0') {
  val += '';
  let numPads = length - val.length;
  if (numPads === 0) { return val; }
  return new Array(numPads + 1).join(padChar) + val;
}

class TimeTrackingPlugin {
  private api: Plugins.PluginApi;
  private logger: Logger;
  private currentPath: {
    row: Row,
    time: number,
  } | null;

  constructor(api) {
    this.api = api;
    this.logger = this.api.logger;
    this.logger.info('Loading time tracking');
    this.currentPath = null;

    // TODO: sequence onRowChange?
    this.onRowChange(null, this.api.cursor.path); // Initial setup, fire and forget
    // NOTE: all these are fire and forget
    this.api.cursor.on('rowChange', this.onRowChange.bind(this));

    this.api.registerHook('document', 'pluginRowContents', async (obj, { row }) => {
      obj.timeTracked = await this.rowTime(row);
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
        const isCurRow = (this.currentPath !== null) && (path.row === this.currentPath.row);

        if (isCurRow || time > 1000) {
          let timeStr = ' ';
          timeStr += (this.printTime(time));
          if (isCurRow) {
            timeStr += ' + ';
          }
          elements.push(
            <span key='time' style={{color: 'lightgray'}}>{timeStr}</span>
          );

          if ((this.currentPath !== null) && isCurRow) {
            const curTime = Date.now() - this.currentPath.time;
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
      await this._rebuildTreeTime(info.row);
      await this._rebuildTreeTime(info.old_parent, true);
    });

    this.api.registerListener('document', 'afterAttach', async (info) => {
      await this._rebuildTreeTime(info.row);
      if (info.old_detached_parent) {
        await this._rebuildTreeTime(info.old_detached_parent, true);
      }
    });

    this.api.registerListener('document', 'afterDetach', async (info) => {
      await this._rebuildTreeTime(info.row);
    });

    this.api.registerListener('session', 'exit', async () => {
      await this.onRowChange(this.currentPath, null);
    });

    this.api.registerAction(
      'toggle-time-tracking',
      'Toggle whether time is being logged',
      async () => {
        return await this.toggleLogging();
      },
    );
    this.api.registerAction(
      'clear-row-time',
      'Clear current row time',
      async () => {
        return await this.resetcurrentPath();
      },
    );
    this.api.registerAction(
      'add-row-time',
      'Add time to current row (in minutes)',
      async ({ repeat }) => {
        return await this.changeTimecurrentPath(repeat);
      },
    );
    this.api.registerAction(
      'subtract-row-time',
      'Subtract time from current row (in minutes)',
      async ({ repeat }) => {
        return await this.changeTimecurrentPath(-repeat);
      },
    );

    this.api.registerDefaultMappings(
      'NORMAL',
      {
        'toggle-time-tracking': [['Z', 'l']],
        'clear-row-time': [['Z', 'c']],
        'add-row-time': [['Z', 'a'], ['Z', '>']],
        'subtract-row-time': [['Z', 's'], ['Z', '<']],
      },
    );

    setInterval(() => {
      if (this.currentPath !== null) {
        let curTime = Date.now() - this.currentPath.time;
        return $('.curtime').text(this.printTime(curTime));
      }
    }, 1000);
  }

  private async changeTimecurrentPath(delta_minutes) {
    if (this.currentPath !== null) {
      let curTime = Date.now() - this.currentPath.time;
      curTime += delta_minutes * 60 * 1000;
      if (curTime < 0) {
        this.currentPath.time = Date.now();
        await this.modifyTimeForRow(this.currentPath.row, curTime);
      } else {
        this.currentPath.time = Date.now() - curTime;
      }
    }
  }

  private async getRowData(row: Row, keytype: string, default_value: any = null) {
    let key = `${row}:${keytype}`;
    return await this.api.getData(key, default_value);
  }

  private async setRowData(row, keytype, value) {
    let key = `${row}:${keytype}`;
    await this.api.setData(key, value);
    await this.api.updatedDataForRender(row);
  }

  private async transformRowData(row, keytype, transform, default_value: any = null) {
    await this.setRowData(
      row, keytype,
      transform(await this.getRowData(row, keytype, default_value))
    );
  }

  private async isLogging() {
    return await this.api.getData('isLogging', true);
  }

  private async toggleLogging() {
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

  private async onRowChange(from, to) {
    if (!(await this.isLogging())) {
      return;
    }
    this.logger.debug(`Switching from row ${from && from.row} to row ${to && to.row}`);
    let time = Date.now();
    if (this.currentPath && this.currentPath.row !== (to && to.row)) {
      await this.modifyTimeForRow(from.row, (time - this.currentPath.time));
      this.currentPath = null;
    }
    if (to !== null) {
      if (this.currentPath === null) {
        this.currentPath = { row: to.row, time };
      }
    }
  }

  private async resetcurrentPath() {
    if (this.currentPath) {
      this.currentPath.time = Date.now();
    }
  }

  private async modifyTimeForRow(row, delta) {
    await this.transformRowData(row, 'rowTotalTime', current => (current + delta), 0);
    await this._rebuildTreeTime(row, true);
  }

  private async _rebuildTotalTime(row) {
    let children = await this.api.session.document._getChildren(row);
    let detached_children = await this.api.session.document.store.getDetachedChildren(row);

    let childTotalTimes = await Promise.all(
      children.concat(detached_children).map(
        async (child_row) => {
          return await this.getRowData(child_row, 'treeTotalTime', 0);
        }
      )
    );
    let rowTime = await this.getRowData(row, 'rowTotalTime', 0);
    let totalTime = childTotalTimes.reduce((a, b) => (a + b), rowTime);
    await this.setRowData(row, 'treeTotalTime', totalTime);
  }

  private async _rebuildTreeTime(row, inclusive = false) {
    const ancestors = await this.api.session.document.allAncestors(row, { inclusive });
    for (let i = 0; i < ancestors.length; i++) {
      const ancestor_row = ancestors[i];
      await this._rebuildTotalTime(ancestor_row);
    }
  }

  private async rowTime(row) {
    return await this.getRowData(row, 'treeTotalTime', 0);
  }

  private printTime(ms) {
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
    description: `
    Keeps track of how much time has been spent in each row
    (including its descendants)
    `,
    version: 3,
  },
  async (api) => {
    return new TimeTrackingPlugin(api);
  },
  (api => api.deregisterAll())
);

