/* Time-tracking keeps track of the amount of time spent in each subtree.

  rowTotalTime:  The amount of time spent on a particular row
  detachedTime:  The amount of time spent in children of a row,
                 where the children were subsequently deleted from the
                 document.
  treeTotalTime: Total amount of time under a row.
                 Cached sum of rowTotalTime, detachedTime, and
                 (recursively) treeTotalTime of all current children.

NOTES:
- Clones are double-counted. This is known and will not be fixed.
  That is, if A contains both B and C, which each have a copy of D cloned,
  A's time will double-count D.
  This probably bad behavior but there is no plan to fix it.
- When a row is completely deleted, its time get counted in its parent
  from right before it got detached.
  If it then gets re-attached, that time gets taken away from the old parent.
*/

import $ from 'jquery';
import * as React from 'react'; // tslint:disable-line no-unused-variable

import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import { Logger } from '../../shared/utils/logger';
import Path from '../../assets/ts/path';
import { Row } from '../../assets/ts/types';

function pad(num: number, length: number, padChar: string = '0') {
  const val = '' + num;
  let numPads = length - val.length;
  if (numPads === 0) { return val; }
  return new Array(numPads + 1).join(padChar) + val;
}

class TimeTrackingPlugin {
  private api: PluginApi;
  private logger: Logger;
  private currentPath: {
    row: Row,
    time: number,
  } | null;
  private isLogging: boolean;

  constructor(api: PluginApi) {
    this.api = api;
    this.logger = this.api.logger;
    this.logger.info('Loading time tracking');
    this.currentPath = null;
    this.isLogging = false;

    this.api.cursor.on('rowChange', async (_oldPath: Path, newPath: Path) => {
      await this.onRowChange(newPath.row);
    });

    this.api.registerListener('document', 'childAdded', async ({ row }) => {
      // for caching
      await Promise.all([
        this._setRowData(row, 'treeTotalTime', 0),
        this._setRowData(row, 'rowTotalTime', 0),
        this._setRowData(row, 'detachedTime', 0),
      ]);
    });

    this.api.registerHook('document', 'pluginRowContents', async (obj, { row }) => {
      obj.timeTracked = await this.rowTime(row);
      return obj;
    });

    this.api.registerHook('session', 'renderAfterLine', (elements, renderData) => {
      const { path, pluginData } = renderData;
      const time = pluginData.timeTracked;
      if (time == null) {
        elements.push(
          <span key='time' style={{color: 'lightgray'}}>{' '}Loading...</span>
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
      if (info.old_detached_parent) {
        const treeTime = await this.getRowData(info.row, 'treeTotalTime', 0);
        await this.transformRowData(info.old_detached_parent, 'detachedTime', current => (current - treeTime), 0);
        await this._rebuildTreeTime(info.old_detached_parent, true);
      }
      await this._rebuildTreeTime(info.row);
    });

    this.api.registerListener('document', 'afterDetach', async (info) => {
      if (info.last) {
        const treeTime = await this.getRowData(info.row, 'treeTotalTime', 0);
        await this.transformRowData(info.parent_row, 'detachedTime', current => (current + treeTime), 0);
      }
      await this._rebuildTreeTime(info.row);
    });

    this.api.registerListener('session', 'exit', async () => {
      // NOTE: this probably doesn't work
      await this.onRowChange(null);
    });

    this.api.registerAction(
      'toggle-time-tracking',
      'Toggle whether time is being logged',
      async () => {
        await this.toggleLogging();
      },
    );
    this.api.registerAction(
      'clear-row-time',
      'Clear current row time',
      async () => {
        await this.resetCurrentPath();
      },
    );
    this.api.registerAction(
      'add-row-time',
      'Add time to current row (in minutes)',
      async ({ repeat }) => {
        await this.changeTimeCurrentPath(repeat);
      },
    );
    this.api.registerAction(
      'subtract-row-time',
      'Subtract time from current row (in minutes)',
      async ({ repeat }) => {
        await this.changeTimeCurrentPath(-repeat);
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
      if (this.currentPath === null) { return; }
      let curTime = Date.now() - this.currentPath.time;
      $('.curtime').text(this.printTime(curTime));
    }, 1000);
  }

  private async changeTimeCurrentPath(delta_minutes: number) {
    if (this.currentPath !== null) {
      let curTime = Date.now() - this.currentPath.time;
      curTime += delta_minutes * 60 * 1000;
      if (curTime < 0) {
        this.currentPath.time = Date.now();
        await this.modifyTimeForRow(this.currentPath.row, curTime);
      } else {
        this.currentPath.time = Date.now() - curTime;
      }
      await this.api.updatedDataForRender(this.currentPath.row);
    }
  }

  private async getRowData(row: Row, keytype: string, default_value: any = null) {
    let key = `${row}:${keytype}`;
    return await this.api.getData(key, default_value);
  }

  private async _setRowData(row: Row, keytype: string, value: any) {
    let key = `${row}:${keytype}`;
    await this.api.setData(key, value);
  }

  private async setRowData(row: Row, keytype: string, value: any) {
    await this._setRowData(row, keytype, value);
    await this.api.updatedDataForRender(row);
  }

  private async transformRowData(
    row: Row, keytype: string,
    transform: (val: number) => number, default_value: any = null) {
    await this.setRowData(
      row, keytype,
      transform(await this.getRowData(row, keytype, default_value))
    );
  }

  public async toggleLogging(forceValue?: boolean) {
    // toggle, by default
    let isLogging = !this.isLogging;
    if (forceValue != null) {
      isLogging = forceValue;
    }

    if (isLogging) {
      this.logger.info('Turning logging on');
      await this.api.setData('isLogging', true);
      if (!this.isLogging) {
        await this.onRowChange(this.api.cursor.row); // Initial setup
      }
    } else {
      this.logger.info('Turning logging off');
      if (this.isLogging) {
        await this.onRowChange(null); // Final close
      }
      await this.api.setData('isLogging', false);
    }
    this.isLogging = isLogging;
  }

  private async onRowChange(to: Row | null) {
    const from: Row | null = (this.currentPath && this.currentPath.row) || null;
    if (!this.isLogging) {
      this.currentPath = null;
      if (from) {
        await this.api.updatedDataForRender(from);
      }
      return;
    }
    if ((from != null) && (from === to)) {
      return;
    }
    this.logger.debug(`Switching from row ${from} to row ${to}`);
    let time = Date.now();
    if (this.currentPath != null) { // if (from != null) doesn't typecheck :(
      await this.modifyTimeForRow(this.currentPath.row, time - this.currentPath.time);
      await this.api.updatedDataForRender(from as Row);
    }
    if (to !== null) {
      this.currentPath = { row: to, time };
      await this.api.updatedDataForRender(to);
    } else {
      this.currentPath = null;
    }
  }

  private async resetCurrentPath() {
    if (this.currentPath) {
      this.currentPath.time = Date.now();
      await this.api.updatedDataForRender(this.currentPath.row);
    }
  }

  private async modifyTimeForRow(row: Row, delta: number) {
    await this.transformRowData(row, 'rowTotalTime', current => (current + delta), 0);
    await this._rebuildTreeTime(row, true);
  }

  private async _rebuildTotalTime(row: Row) {
    let children = await this.api.session.document._getChildren(row);
    const times = await Promise.all(
      children.map(
        async (child_row) => {
          return await this.getRowData(child_row, 'treeTotalTime', 0);
        }
      ).concat([
        this.getRowData(row, 'detachedTime', 0),
        this.getRowData(row, 'rowTotalTime', 0),
      ])
    );

    const totalTime = times.reduce((a, b) => (a + b), 0);
    await this.setRowData(row, 'treeTotalTime', totalTime);
  }

  private async _rebuildTreeTime(row: Row, inclusive = false) {
    const ancestors = await this.api.session.document.allAncestors(row, { inclusive });
    for (let i = 0; i < ancestors.length; i++) {
      const ancestor_row = ancestors[i];
      await this._rebuildTotalTime(ancestor_row);
    }
  }

  private async rowTime(row: Row) {
    return await this.getRowData(row, 'treeTotalTime', 0);
  }

  private printTime(ms: number) {
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

registerPlugin<TimeTrackingPlugin>(
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
    const timeTracking = new TimeTrackingPlugin(api);
    // Initial setup
    await timeTracking.toggleLogging(
      await api.getData('isLogging', true)
    );
    return timeTracking;
  },
  (api => api.deregisterAll())
);

