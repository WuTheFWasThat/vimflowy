import * as React from 'react'; // tslint:disable-line no-unused-variable
import * as _ from 'lodash';
import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import { Logger } from '../../shared/utils/logger';
import Path from '../../assets/ts/path';
import { SerializedBlock, Row } from '../../assets/ts/types';
import { CachedRowInfo } from '../../assets/ts/document';
import { matchWordRegex } from '../../assets/ts/utils/text';
import { pluginName as marksPluginName, MarksPlugin } from '../marks';

registerPlugin<DeadlinesPlugin>(
  {
    name: 'Deadlines',
    author: 'Victor Tao',
    description: (
    <div>
    <ul>
        <li> Creates a "Deadlines" node at the root</li>
        <li> Add a deadline to a node by adding a child of the form "due YYYY-MM-DD" or "due MM-DD"</li>
        <li> All new deadlines will be automatically cloned in the Deadlines node in sorted order</li>
        <li> Requires marks plugin to mark the "Deadlines" node </li>
    </ul>
    </div>
    ),
    version: 1,
    dependencies: [marksPluginName],
  },
  async (api) => {
    const deadlines = new DeadlinesPlugin(api);
    // Initial setup
    if (process.env.NODE_ENV === 'production') {
      await api.setData('isLogging', false);
    } else {
      await api.setData('isLogging', true);
    }
    await deadlines.init();
    return deadlines;
  },
  (api => api.deregisterAll())
);

class DeadlinesPlugin {
  private api: PluginApi;
  private logger: Logger;
  private isLogging: boolean;
  private deadlinesRoot: Path | null;
  private detachTimer: any;

  constructor(api: PluginApi) {
    this.api = api;
    this.logger = this.api.logger;
    this.logger.info('Loading Deadlines');
    this.isLogging = false;
    this.deadlinesRoot = null;
    this.detachTimer = null;

    // this.setLogging();

    this.api.cursor.on('rowChange', async (_oldPath: Path, newPath: Path) => {
      this.log('rowChange', _oldPath, newPath);
      this.checkForDates(_oldPath);
    });

    this.api.registerListener('document', 'afterDetach', async (info) => {
      let that = this;
      if (this.detachTimer) {
        clearTimeout(this.detachTimer);
      }
      this.detachTimer = setTimeout(async function() {
        await that.checkDeleted(info);
      }, 1000);
    });
  }

  public async setLogging() {
    this.isLogging = await this.api.getData('isLogging', true);
  }

  public async init() {
    this.log('init');
    this.getDeadlinesRoot();
  }

  private async checkForDates(path: Path, text?: string) {
    this.log('checkForDates', path);
    if (!text) {
      text = await this.api.session.document.getText(path.row);
    }
    if (!text) {
      return;
    }
    const date = await this.parseDate(text);
    if (date && path.parent) {
      const inDeadlines = await this.inDeadlines(path.parent.row);
      if (!inDeadlines) {
        await this.createDeadlineClone(path.parent.row, date);
      }
    }
  }

  private async inDeadlines(row: Row) {
    // check if row is in top level of deadlines
    this.log('inDeadlines', row);
    const root = await this.getDeadlinesRoot();
    const document = this.api.session.document;
    const info = await document.getInfo(row);
    const parents = info.parentRows;
    return parents.includes(root.row);
  }

  private async createDeadlineClone(row: Row, thisDate: Date) {
    this.log('createDeadlineClone', row, thisDate);
    const root = await this.getDeadlinesRoot();
    let index = 0;
    const children = await this.getChildren(root);
    for (const child of children) {
      const date = await this.getDate(child);
      if (date && thisDate < date) {
        break;
      }
      index++;
    }
    this.log('createDeadlineClone attachBlocks', root, row, index);

    await this.api.session.attachBlocks(root, [row], index);
    await this.api.updatedDataForRender(row);
  }

  private async getDate(path: Path) {
    // get date of a deadline
    this.log('getDate', path);
    const children = await this.getChildren(path);
    for (const child of children) {
      const text = await this.api.session.document.getText(child.row);
      const date = await this.parseDate(text);
      if (date) {
        return date;
      }
    }
    return null;
  }

  private async parseDate(text: string) {
    // return Date or null if invalid
    this.log('parseDate', text);
    return this.parseFullDate(text);  // might add more parse options
  }

  private async parseFullDate(text: string) {
    this.log('parseFullDate', text);
    const regex = matchWordRegex('due ((\\d+\\-)?\\d+\\-\\d+)');
    let match = regex.exec(text.toLowerCase());
    if (match) {
      this.log('Matched', match);
      const d = match[2].split('-').map((Number));
      let dateStr = match[2];
      const today = new Date();
      if (d.length === 2) {
        dateStr = today.getFullYear().toString() + '-' + dateStr;
      }
      const date = new Date(Date.parse(dateStr));
      const lastWeek = new Date(today);
      lastWeek.setDate(today.getDate() - 7);
      if (d.length === 2 && date < lastWeek) {
        date.setFullYear(date.getFullYear() + 1);
      }
      this.log('parseFullDate', d, date);
      return date;
    }
    return null;
  }

  private async checkDeleted(info: CachedRowInfo) {
    this.log('checkDeleted', info);
    let needReInit = false;
    const root = await this.getDeadlinesRoot();
    if (root) {
      if (info.row === root.row) {
        needReInit = true;
      }
    }
    if (needReInit) {
      this.log('needReInit', true);
      this.deadlinesRoot = null;
      await this.init();
    }
  }

  public async log(...args: any[]) {
    if (this.isLogging) {
      this.logger.info('Deadlines: ', ...args);
    }
  }

  private async getMarkPath(mark: string): Promise<Path | null> {
    this.log('getMarkPath', mark);
    const marksPlugin = this.api.getPlugin(marksPluginName) as MarksPlugin;
    const marks = await marksPlugin.listMarks();
    this.log('getMarkPath', marks, mark);
    return marks[mark];
  }

  private async getDeadlinesRoot() {
    this.log('getDeadlinesRoot');
    if (this.deadlinesRoot && this.api.session.document.isValidPath(this.deadlinesRoot!)) {
      this.log('getDeadlinesRoot from cache');
      return this.deadlinesRoot!;
    } else {
      let deadlinesRoot = await this.getMarkPath('deadlines');
      if (!deadlinesRoot) {
        await this.createDeadlinesRoot();
        deadlinesRoot = await this.getMarkPath('deadlines');
        if (!deadlinesRoot) {
          throw new Error('Error while creating node');
        }
      }
      this.deadlinesRoot = deadlinesRoot;
      return deadlinesRoot!;
    }
  }

  private async setMark(path: Path, mark: string) {
    this.log('setMark', path, mark);
    const marksPlugin = this.api.getPlugin(marksPluginName) as MarksPlugin;
    const setMark = await marksPlugin.setMark(path.row, mark);
    this.log('setMark', setMark);
  }

  public async getChildren(parent_path: Path): Promise<Array<Path>> {
    if (!parent_path) {
      return [];
    }
    return (await this.api.session.document.getChildren(parent_path)).map(path => parent_path.child(path.row));
  }

  private async createBlock(path: Path, text: string, isCollapsed: boolean = true, plugins?: any) {
    let serialzed_row: SerializedBlock = {
      text: text,
      collapsed: isCollapsed,
      plugins: plugins,
      children: [],
    };
    this.log('createBlock', path, text, isCollapsed, plugins, serialzed_row);
    const paths = await this.api.session.addBlocks(path, 0, [serialzed_row]);
    if (paths.length > 0) {
      this.log('Block created', path, text);
      await this.api.updatedDataForRender(path.row);
      return paths[0];
    } else {
      throw new Error('Error while creating block');
    }
  }

  private async createDeadlinesRoot() {
    this.log('createDeadlines');
    const path = await this.createBlock(this.api.session.document.root, 'Deadlines');
    if (path) {
      await this.setMark(path, 'deadlines');
    }
  }
}
