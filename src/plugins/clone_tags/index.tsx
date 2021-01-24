import * as _ from 'lodash';
import * as React from 'react'; // tslint:disable-line no-unused-variable

import { Logger } from '../../shared/utils/logger';

import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import Path from '../../assets/ts/path';
import { Row, SerializedBlock } from '../../assets/ts/types';

import { pluginName as marksPluginName, MarksPlugin } from '../marks';
import { pluginName as tagsPluginName, TagsPlugin } from '../tags';

// TODO: do this elsewhere
declare const process: any;

type Tag = string;

/*
 * ALGORITHMIC NOTE: maintaining the set of tags
 * Rather than trying to update the list
 * as rows get removed and added from the document (which is especially
 * tricky because of cloning),
 * we simply store all tags, even if attached to the document,
 * and then prune after looking them up.
 */

export class CloneTagsPlugin {
  private api: PluginApi;
  private logger: Logger;
  private tagRoot: {[tag: string]: Path | null};
  private tagsPlugin: TagsPlugin;

  constructor(api: PluginApi) {
    this.api = api;
    this.logger = this.api.logger;
    this.tagRoot = {};
    this.tagsPlugin = this.api.getPlugin(tagsPluginName) as TagsPlugin;
  }

  public async enable() {
    this.logger.debug('Enabling cloning tags');

    this.api.registerHook('document', 'tagAdded', async (_struct, { tag, row }) => {
      await this.createClone(row, tag);
    });

    this.api.registerHook('document', 'tagRemoved', async (_struct, { tag, row }) => {
      await this.deleteClone(row, tag);
    });
  }

  public async inTagRoot(row: Row, tag: Tag) {
    // check if row is in top level of tag root
    const root = await this.getTagRoot(tag);
    const document = this.api.session.document;
    const info = await document.getInfo(row);
    const parents = info.parentRows;
    return parents.includes(root.row);
  }

  public async createClone(row: Row, tag: Tag) {
    const root = await this.getTagRoot(tag);
    if (!await this.inTagRoot(row, tag)) {
      await this.api.session.attachBlocks(root, [row], 0);
      await this.api.updatedDataForRender(row);
    }
  }

  public async deleteClone(row: Row, tag: Tag) {
    if (!await this.inTagRoot(row, tag)) {
      return;
    }
    const root = await this.getTagRoot(tag);
    const document = this.api.session.document;
    if (!root) {
      return;
    }
    await document._detach(row, root.row);
    await this.api.updatedDataForRender(row);
  }

  private async getMarkPath(mark: string): Promise<Path | null> {
    const marksPlugin = this.api.getPlugin(marksPluginName) as MarksPlugin;
    const marks = await marksPlugin.listMarks();
    return marks[mark];
  }

  public async getTagRoot(tag: Tag): Promise<Path> {
    let root = this.tagRoot[tag];
    if (root && await this.api.session.document.isValidPath(root) && await this.api.session.document.isAttached(root.row)) {
      return root;
    } else {
      root = await this.getMarkPath(tag);
      if (!root) {
        await this.createTagRoot(tag);
        root = await this.getMarkPath(tag);
        if (!root) {
          throw new Error('Error while creating node');
        }
      }
      this.tagRoot[tag] = root;
      return root;
    }
  }

  private async setMark(path: Path, mark: string) {
    const marksPlugin = this.api.getPlugin(marksPluginName) as MarksPlugin;
    await marksPlugin.setMark(path.row, mark);
  }

  private async createBlock(path: Path, text: string, isCollapsed: boolean = true, plugins?: any) {
    let serialzed_row: SerializedBlock = {
      text: text,
      collapsed: isCollapsed,
      plugins: plugins,
      children: [],
    };
    const paths = await this.api.session.addBlocks(path, 0, [serialzed_row]);
    if (paths.length > 0) {
      await this.api.updatedDataForRender(path.row);
      return paths[0];
    } else {
      throw new Error('Error while creating block');
    }
  }

  private async createTagRoot(tag: Tag) {
    const path = await this.createBlock(this.api.session.document.root, tag);
    if (path) {
      await this.setMark(path, tag);
    }
    const tagsToRows = await this.tagsPlugin._getTagsToRows();
    const document = this.api.session.document;
    for (let row of tagsToRows[tag]) {
      if (await document.isAttached(row)) {
        await this.createClone(row, tag);
      }
    }
  }
}

export const pluginName = 'Tag Clone';

registerPlugin<CloneTagsPlugin>(
  {
    name: pluginName,
    author: 'Victor Tao',
    description:
      `Creates a root node for every tag with mark [TAGNAME]. Tagged rows are cloned to to this node.`,
    version: 1,
    dependencies: [tagsPluginName, marksPluginName],
  },
  async (api) => {
    const clonetagsPlugin = new CloneTagsPlugin(api);
    await clonetagsPlugin.enable();
    return clonetagsPlugin;
  },
  (api) => api.deregisterAll(),
);
