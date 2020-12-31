import * as React from 'react'; // tslint:disable-line no-unused-variable
import * as _ from 'lodash';
import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import { Logger } from '../../shared/utils/logger';
import Path from '../../assets/ts/path';
import { SerializedBlock } from '../../assets/ts/types';
import { CachedRowInfo } from '../../assets/ts/document';
import { matchWordRegex } from '../../assets/ts/utils/text';
import { pluginName as marksPluginName, MarksPlugin } from '../marks';

registerPlugin<DailyNotesPlugin>(
  {
    name: 'Daily Notes',
    author: 'shady2k',
    description: (
    <div>
    How to use:
    <ul>
      <li>
          This plugin automatically creates a "Daily Notes" node at the root.
          Sub-nodes are created automatically every day (if missing, they can also be manually created).
          Paths to sub-nodes have YYYY, YYYY-MM and YYYY-MM-DD date formats.
      </li>
      <li> Marks plugin required: easy navigation between today, tommorrow and yesterday nodes (created every day automatically)</li>
      <li> All new records will be automatically cloned in the today node</li>
      <li> Adding a date in format YYYY-MM-DD will create that day in the Daily Notes subtree as a Linked node</li>
    </ul>
    </div>
    ),
    version: 1,
    dependencies: [marksPluginName],
  },
  async (api) => {
    const dailyNotes = new DailyNotesPlugin(api);
    // Initial setup
    if (process.env.NODE_ENV === 'production') {
      await api.setData('isLogging', false);
    } else {
      await api.setData('isLogging', true);
    }
    await dailyNotes.init();
    return dailyNotes;
  },
  (api => api.deregisterAll())
);

class DailyNotesPlugin {
  private api: PluginApi;
  private logger: Logger;
  private isLogging: boolean;
  private dailyMarks: any;
  private childAddedArr: Array<number>;
  private dailyNotesRoot: Path | null;
  private lastRowText: string | null;
  private detachTimer: any;

  constructor(api: PluginApi) {
    this.api = api;
    this.logger = this.api.logger;
    this.logger.info('Loading Daily notes');
    this.isLogging = false;
    this.childAddedArr = [];
    this.dailyNotesRoot = null;
    this.lastRowText = null;
    this.detachTimer = null;

    this.setLogging();

    this.api.cursor.on('rowChange', async (_oldPath: Path, newPath: Path) => {
      this.log('rowChange', _oldPath, newPath);
      this.checkNewDay();
      this.checkRowTextChanged(_oldPath, newPath);
    });

    this.api.registerListener('document', 'childAdded', async ({ row }) => {
      this.log('childAdded', row);
      this.childAddedArr.push(row);
    });

    this.api.registerListener('document', 'loadRow', async (path, serialized) => {
      const ci = _.findIndex(this.childAddedArr, ce => ce === path.row);
      if (ci !== -1) {
        this.log('loadRow', path, serialized);
        this.childAddedArr.splice(ci, 1);
        this.addCreatedToday(path.row);
      }
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

    /*this.api.registerListener('session', 'exit', async () => {
      this.log('exit');
    });*/
  }

  public async setLogging() {
    this.isLogging = await this.api.getData('isLogging', false);
  }

  public async init() {
    this.log('init');
    await this.initDailyMarks();
    await this.checkDailyMarks();

    for (const item of this.dailyMarks) {
      if (item.date && item.mark) {
        await this.createDailyNode(item.id, item.date, item.mark);
      }
    }
  }

  private async initDailyMarks() {
    const dt = new Date();
    let dt_tomorrow = new Date();
    dt_tomorrow.setDate(dt.getDate() + 1);
    let dt_yesterday = new Date();
    dt_yesterday.setDate(dt.getDate() - 1);

    this.dailyMarks = [
      { id: 'tomorrow', mark: 'tomorrow', date: dt_tomorrow, node: null, linkedNode: null },
      { id: 'today', mark: 'today', date: dt, node: null, linkedNode: null },
      { id: 'yesterday', mark: 'yesterday', date: dt_yesterday, node: null,  linkedNode: null },
    ];
  }

  private async checkNewDay() {
    this.log('checkNewDay');
    if (this.isNewDay()) {
      this.log('New day comes');
      this.initDailyMarks();
      await this.init();
    } else {
      this.log('Same day');
    }
  }

  private isNewDay() {
    this.log('isNewDay');
    const te = this.dailyMarks.find((e: any) => {
      return e.id === 'today';
    });
    let dt = new Date();
    let dt2 = te.date;

    if (dt && dt2) {
      if (dt.setHours(0, 0, 0, 0) === dt2.setHours(0, 0, 0, 0)) {
        return false;
      } else {
        return true;
      }
    } else {
      throw new Error('Can\'t get dates');
    }
  }

  private async checkRowTextChanged(oldPath: Path, newPath: Path) {
    if (oldPath !== newPath) {
      const rowTextOld = await this.api.session.document.getText(oldPath.row);
      if (this.lastRowText !== null && this.lastRowText !== rowTextOld) {
        this.log('Row text changed', oldPath);
        this.checkForDates(oldPath, rowTextOld);
      }
      this.lastRowText = await this.api.session.document.getText(newPath.row);
    }
  }

  private isValidDate(year: number, month: number, day: number) {
    const d = new Date(year, month, day);
    if (d.getFullYear() === year && d.getMonth() === month && d.getDate() === day) {
        return true;
    }
    return false;
  }

  private async checkForDates(path: Path, text?: string) {
    if (!text) {
      text = await this.api.session.document.getText(path.row);
    }
    if (!text) {
      return;
    }
    const regex = matchWordRegex('\\d{4}\\-\\d{2}\\-\\d{2}');
    let match = regex.exec(text);
    if (match) {
      this.log('Matched', match);
      const dateStr = match[1];
      const date = new Date(Date.parse(dateStr));
      const d = match[1].split('-');
      if (d.length === 3) {
        const isValidDate = this.isValidDate(Number.parseInt(d[0]), Number.parseInt(d[1]), Number.parseInt(d[2]));
        if (isValidDate) {
          const newDay = { id: dateStr, mark: null, date: date, node: null,  linkedNode: null };
          this.dailyMarks.push(newDay);
          await this.createDailyNode(dateStr, date, null);
          const linkedNode = this.getLinkedNode(dateStr);
          await this.addLinked(linkedNode, path.row, true);
        }
      }
    }
  }

  private async checkDeleted(info: CachedRowInfo) {
    this.log('checkDeleted', info);
    let needReInit = false;
    const root = await this.getDailyNotesRoot();
    for (const item of this.dailyMarks) {
      if (item.node) {
        if (info.row === item.node.row) {
          needReInit = true;
        }
      }
      if (item.linkedNode) {
        if (info.row === item.linkedNode.row) {
          needReInit = true;
        }
      }
    }
    if (root) {
      if (info.row === root.row) {
        needReInit = true;
      }
    }
    if (needReInit) {
      this.log('needReInit', true);
      this.dailyNotesRoot = null;
      await this.init();
    }
  }

  private isHasRows(path: Path | null, searchRows: number[]): any {
    if (path) {
      let isFound = false;
      for (const element of searchRows) {
        if (path.row === element) {
          isFound = true;
          break;
        }
      }
      if (isFound) {
        return true;
      } else {
        if (path.parent) {
          return this.isHasRows(path.parent, searchRows);
        } else {
          return false;
        }
      }
    } else {
      return false;
    }
  }

  private async addLinked(linkedNode: Path, row: number, createInDailyNode: boolean = false) {
    this.log('addLinked', row);
    let foundInDailyNode = false;
    let can = await this.api.session.document.canonicalPath(row);

    // Check row in Daily node
    if (!createInDailyNode) {
      const rootNode = await this.getDailyNotesRoot();
      foundInDailyNode = this.isHasRows(can, [rootNode.row]);
    }

    // Check row in Linked node
    let foundLinked = false;
    let linkedNodeChildren = await this.getChildren(linkedNode);
    if (linkedNodeChildren) {
      let linkedNodeChildrenArr: number[] = [];
      linkedNodeChildren.map(element => linkedNodeChildrenArr.push(element.row));
      foundLinked = this.isHasRows(can, linkedNodeChildrenArr);
    }

    if (!foundInDailyNode && !foundLinked) {
      this.log('Create clone', row);
      let rowsToClone: number[] = [];
      rowsToClone.push(row);
      if (linkedNode) {
        this.api.session.attachBlocks(linkedNode, rowsToClone, 0);
      }
    }
  }

  private async addCreatedToday(row: number) {
    this.log('addCreatedToday', row);
    const linkedNode = this.getLinkedNode('today');
    await this.addLinked(linkedNode, row);
  }

  /*private getNode(id: string) {
    this.log('getNode', id);
    const found = this.dailyMarks.find((e: any) => {
      return e.id === id;
    });
    return found.node;
  }*/

  private setNode(id: string, path: Path) {
    this.log('setNode', id, path);
    const found = this.dailyMarks.find((e: any) => {
      return e.id === id;
    });
    found.node = path;
  }

  private getLinkedNode(id: string) {
    this.log('getLinkedNode', id);
    const found = this.dailyMarks.find((e: any) => {
      return e.id === id;
    });
    return found.linkedNode;
  }

  private setLinkedNode(id: string, path: Path) {
    this.log('setLinkedNode', id, path);
    const found = this.dailyMarks.find((e: any) => {
      return e.id === id;
    });
    found.linkedNode = path;
  }

  private async checkDailyMarks() {
    this.log('checkDailyMarks');
    const marksPlugin = this.api.getPlugin(marksPluginName) as MarksPlugin;
    const paths = this.traverseSubtree(await this.getDailyNotesRoot());
    for await (let path of paths) {
      const mark = await marksPlugin.getMark(path.row);
      if (mark !== null) {
        const found = this.dailyMarks.find((e: any) => {
          return e.mark === mark;
        });

        if (found) {
          this.log('checkDailyMarks', 'Clear mark', found.mark);
          await this.setMark(path, null);
        }
      }
    }
  }

  private getNodeText(dt: Date, mode: string) {
    const year = dt.getFullYear().toString();
    const month = ('0' + (dt.getMonth() + 1).toString()).slice(-2);
    const day = ('0' + dt.getDate().toString()).slice(-2);
    if (mode === 'year') {
      return year;
    } else if (mode === 'month') {
      return [year, month].join('-');
    } else {
      return [year, month, day].join('-');
    }
  }

  public async log(...args: any[]) {
    if (this.isLogging) {
      this.logger.info('Daily notes: ', ...args);
    }
  }

  private async getNodeWithText(root: Path, text: String): Promise<Path | null> {
    this.log('getNodeWithText', root, text);
    const document = this.api.session.document;
    if (await document.hasChildren(root.row)) {
      const children = await document.getChildren(root);
      for await (let child of children) {
        if (await document.getText(child.row) === text) {
          return child;
        }
      }
    }
    return null;
  }

  private async getDailyNotesRoot() {
    this.log('getDailyNotesRoot');
    if (this.dailyNotesRoot && this.api.session.document.isValidPath(this.dailyNotesRoot!)) {
      this.log('getDailyNotesRoot from cache');
      return this.dailyNotesRoot!;
    } else {
      let dailyNotesRoot = await this.getNodeWithText(this.api.session.document.root, 'Daily Notes');
      if (!dailyNotesRoot) {
        await this.createDailyNotesRoot();
        dailyNotesRoot = await this.getNodeWithText(this.api.session.document.root, 'Daily Notes');
        if (!dailyNotesRoot) {
          throw new Error('Error while creating node');
        }
      }
      this.dailyNotesRoot = dailyNotesRoot;
      return dailyNotesRoot!;
    }
  }

  private async setMark(path: Path, mark: string | null) {
    this.log('setMark', path, mark);
    const marksPlugin = this.api.getPlugin(marksPluginName) as MarksPlugin;
    await marksPlugin.setMark(path.row, mark);
  }

  private async* traverseSubtree(root: Path): AsyncIterableIterator<Path> {
    const visited_rows: {[row: number]: boolean} = {};
    let that = this;

    async function* helper(path: Path): AsyncIterableIterator<Path> {
      if (path.row in visited_rows) {
        return;
      }
      visited_rows[path.row] = true;
      yield path;
      const children = await that.getChildren(path);
      for (let i = 0; i < children.length; i++) {
        yield* await helper(children[i]);
      }
    }
    yield* await helper(root);
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
    await this.api.session.addBlocks(path, 0, [serialzed_row]);
    const result = await this.getNodeWithText(path, text);
    this.log('Block created', path, text);
    if (!result) {
      throw new Error('Error while creating block');
    }
    await this.api.updatedDataForRender(path.row);
    return result;
  }

  private async createDailyNotesRoot() {
    this.log('createDailyNotes');
    await this.createBlock(this.api.session.document.root, 'Daily Notes');
  }

  private async createDailyNode(id: string, dt: Date, mark: string | null) {
    this.log('createDailyNode', dt, mark);
    const root = await this.getDailyNotesRoot();

    const yearNode = this.getNodeText(dt, 'year');
    const monthNode = this.getNodeText(dt, 'month');
    const dayNode = this.getNodeText(dt, 'day');

    let yearPath = await this.getNodeWithText(root, yearNode);
    if (!yearPath) {
      yearPath = await this.createBlock(root, yearNode);
    }

    let monthPath = await this.getNodeWithText(yearPath, monthNode);
    if (!monthPath) {
      monthPath = await this.createBlock(yearPath, monthNode);
    }

    let dayPath = await this.getNodeWithText(monthPath, dayNode);
    if (!dayPath) {
      dayPath = await this.createBlock(monthPath, dayNode, true, { mark: mark });
    } else {
      if (mark) {
        this.setMark(dayPath, mark);
      }
    }
    this.setNode(id, dayPath);

    let linkedPath = await this.getNodeWithText(dayPath, 'Linked');
    if (!linkedPath) {
      linkedPath = await this.createBlock(dayPath, 'Linked', false);
    }
    this.setLinkedNode(id, linkedPath);
  }
}
