import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import { Logger } from '../../shared/utils/logger';
import Path from '../../assets/ts/path';
import { SerializedBlock } from '../../assets/ts/types';

registerPlugin<DailyNotesPlugin>(
  {
    name: 'Daily notes',
    author: 'shady2k',
    description: `
    Daily notes
    `,
    version: 1,
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

  constructor(api: PluginApi) {
    this.api = api;
    this.logger = this.api.logger;
    this.logger.info('Loading Daily notes');
    this.isLogging = false;

    this.setLogging();
    this.initDailyMarks();

    this.api.cursor.on('rowChange', async () => {
      this.log('rowChange');
      this.checkNewDay();
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
    await this.checkDailyMarks();
    for (let mark in this.dailyMarks) {
      await this.createDailyNode(this.dailyMarks[mark].date, this.dailyMarks[mark].mark);
    }
  }

  private initDailyMarks() {
    const dt = new Date();
    let dt_tomorrow = new Date();
    dt_tomorrow.setDate(dt.getDate() + 1);
    let dt_yesterday = new Date();
    dt_yesterday.setDate(dt.getDate() - 1);

    this.dailyMarks = [
      { mark: 'tomorrow', date: dt_tomorrow },
      { mark: 'today', date: dt },
      { mark: 'yesterday', date: dt_yesterday },
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
      return e.mark === 'today';
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

  private async checkDailyMarks() {
    this.log('checkDailyMarks');
    const paths = this.traverseSubtree(await this.getDailyNotesRoot());
    for await (let path of paths) {
      const info = await this.api.session.document.getInfo(path.row);
      if (info.pluginData.marks && info.pluginData.marks.mark && info.pluginData.marks.mark !== '') {
        const found = this.dailyMarks.find((e: any) => {
          return e.mark === info.pluginData.marks.mark;
        });

        if (found) {
          this.log('checkDailyMarks', 'Clear mark', found.mark);
          await this.setMark(path, '');
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
    if (document.hasChildren(root.row)) {
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
    let dailyNotesRoot = await this.getNodeWithText(this.api.session.document.root, 'Daily Notes');
    if (!dailyNotesRoot) {
      await this.createDailyNotesRoot();
      dailyNotesRoot = await this.getNodeWithText(this.api.session.document.root, 'Daily Notes');
      if (!dailyNotesRoot) {
        throw new Error('Error while creating node');
      }
    }
    return dailyNotesRoot;
  }

  private async setMark(path: Path, mark: string) {
    this.log('setMark', path, mark);
    let info = await this.api.session.document.getInfo(path.row);
    if (info.pluginData && info.pluginData.marks && info.pluginData.marks.mark !== mark) {
      this.log('Change mark', path, mark);
      info.pluginData.marks.mark = mark;
      await this.api.session.document.emitAsync('loadRow', path, info.pluginData.marks || {});
      await this.api.updatedDataForRender(path.row);
    }
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

  private async createDailyNode(dt: Date, mark: string) {
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
      this.setMark(dayPath, mark);
    }
  }
}


