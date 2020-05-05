import * as React from 'react'; // tslint:disable-line no-unused-variable

// tslint:disable-next-line:max-line-length
import { registerPlugin, PluginApi } from '../../assets/ts/plugins';
import { Logger } from '../../shared/utils/logger';
import { matchWordRegex } from '../../assets/ts/utils/text';
import Session from '../../assets/ts/session';
import * as _ from 'lodash';
import { Row, SerializedBlock } from '../../assets/ts/types';
import Path from '../../assets/ts/path';

// TODO:
// - move all from _getChildren to getChildren which is based on path rather than row.
// - use line renderHooks to automatically detect if GTD tag is present or not and clone it.
// - Support link to original parent in gtd tasks.
class GtdHelperPlugin {
    private api: PluginApi;
    private logger: Logger;
    private gtdRegex: RegExp;
    private loggerPrefix: string;
    private gtdContainedRows: _.Dictionary<Set<any>>;
    private clonedRows: Set<Row>;
    private gtdNodeRow: Row;
    private nodesUpdatedCounter: number;


    constructor(api: PluginApi) {
        this.api = api;
        this.logger = this.api.logger;
        this.gtdRegex = matchWordRegex('\\#\\w+?');
        this.loggerPrefix = 'GTD Plugin: ';
        this.gtdContainedRows = {};
        this.clonedRows = new Set<Row>();
        this.gtdNodeRow = -1;
        this.nodesUpdatedCounter = 0;

        this.api.registerAction(
            'generate-gtd-tasks',
            'Generates GTD tasks for the document',
            async ({ session }) => {
                await this.processGtdAction(session);
            },
        );


        this.api.registerDefaultMappings(
            'NORMAL',
            {
                'generate-gtd-tasks': [['ctrl+t']],
            },
        );
    }

    private log(message: any) {
        this.logger.info(this.loggerPrefix + message.toString());
    }

    private async getChildWithText(row: Row, text: string): Promise<Row> {
        if (await this.api.session.document.hasChildren(row)) {
            let children = await this.api.session.document._getChildren(row);

            let foundRow: Row = -1;
            await Promise.all(children.map(async (child_row) => {
                let child_text = await this.api.session.document.getText(child_row);
                if (child_text.toLowerCase() === text.toLowerCase()) {
                    foundRow = child_row;
                }
            }));

            return foundRow;
        }
        return -1;
    }

    private async getGtdNode() {
        this.gtdNodeRow = await this.getChildWithText(this.api.session.document.root.row, 'gtd');
    }

    private async processGtdAction(session: Session) {
        this.gtdContainedRows = {};
        this.clonedRows = new Set<Row>();
        this.nodesUpdatedCounter = 0;

        await this.getGtdNode();
        if (this.gtdNodeRow === -1) {
            this.api.showAlert('Create GTD node in root');
            return;
        }

        await this.cleanAndFindCurrentGtdNodes();
        await this.findAllGtdTaggedRows(session.document.root.row);
        await this.cloneGtdRows();

        await this.api.session.showMessage('Number of nodes added/updated: ' + this.nodesUpdatedCounter);
    }

    private async findAllGtdTaggedRows(row: Row) {
        if (row === this.gtdNodeRow) {
            // don't parse gtd content.
            return;
        }
        let text = await this.api.session.document.getText(row);
        let match = this.gtdRegex.exec(text);
        if (match) {
            // only process if it's not a clone.
            // if it's a clone then it's already being tracked.
            let isClone = await this.api.session.document.isClone(row);
            if (!isClone) {
                let gtdKeyword = match[1];
                this.log('found hashed on ' + row + ' ' + gtdKeyword);
                if (this.gtdContainedRows[gtdKeyword] === undefined) {
                    this.gtdContainedRows[gtdKeyword] = new Set<any>();
                }
                this.gtdContainedRows[gtdKeyword].add(row);
            }
        }

        if (await this.api.session.document.hasChildren(row)) {
            let children = await this.api.session.document._getChildren(row);

            await Promise.all(children.map(async (child_row) => {
                await this.findAllGtdTaggedRows(child_row);
            }));
        }
    }

    // Takes care of removing un-tagged nodes in GTD and
    // also takes care of removing nodes who's parent doesn't match
    // the gtd topic.
    private async cleanAndFindCurrentGtdNodes() {
        let gtdTopicNodes = await this.api.session.document._getChildren(this.gtdNodeRow);

        await Promise.all(gtdTopicNodes.map(async (topicNodeRow) => {
            let topic = await this.api.session.document.getText(topicNodeRow);
            let gtdTaskNodes = await this.api.session.document._getChildren(topicNodeRow);

            gtdTaskNodes.forEach(async (child_row) => {
                let child_text = await this.api.session.document.getText(child_row);
                if (child_text.toLowerCase().indexOf(topic) === -1) {
                    // contains the wrong gtd topic in the gtd task. Needs to be removed.
                    const index = _.findIndex(gtdTaskNodes, sib => sib === child_row);
                    await this.api.session.delBlocks(topicNodeRow, index, 1, {});
                    await this.api.updatedDataForRender(child_row);
                    this.log('Deleting Cloned Node: ' + child_row + ' as it\'s gtd topic doesn\'t match ' + topic);
                    this.nodesUpdatedCounter += 1;
                } else {
                    this.clonedRows.add(child_row);
                }
            });
        }));
    }

    private async cloneGtdRows() {
        const gtdPath = new Path(this.api.session.document.root, this.gtdNodeRow);
        if (gtdPath.parent == null) {
            throw new Error('Cursor was at root');
        }

        for (let key in this.gtdContainedRows) {
            let gtdrows = this.gtdContainedRows[key];
            let rowsToClone = new Set<any>();
            for (let val of Array.from(gtdrows.values())) {
                if (this.clonedRows.has(Number(val))) {
                    this.log('Skipping to clone row = ' + val + ' as it\'s already cloned');
                } else {
                    this.log('Need to clone row = ' + val);
                    rowsToClone.add(val);
                }
            }

            await this.addClonedRows(gtdPath, key, Array.from(rowsToClone.values()));
        }

        this.api.updatedDataForRender(this.gtdNodeRow);
    }

    private async addClonedRows(path: Path, key: string, rows: Array<Row>) {
        if (rows.length <= 0) {
            return;
        }

        let keyNodeRow = await this.getChildWithText(path.row, key);

        if (keyNodeRow === -1) {
            this.log(key + ' based node doesn\'t exist. Creating it');

            // const index = await this.api.session.document.indexInParent(path);
            let serialzed_row: SerializedBlock = {
                text: key,
                collapsed: false,
                children: [],
            };
            await this.api.session.addBlocks(path, 0, [serialzed_row], {});
        }

        keyNodeRow = await this.getChildWithText(path.row, key);

        this.log('Cloning for key = ' + key + ' containing rows = ' + rows);
        this.api.session.attachBlocks(new Path(path, keyNodeRow), rows, 0, { setCursor: 'first' });
        this.nodesUpdatedCounter += rows.length;
        await this.api.updatedDataForRender(path.row);
    }
}


registerPlugin(
    {
        name: 'GTD Helper',
        author: 'Nikhil Sonti',
        description: (
            <div>
                GTD helper is plugin to support GTD workflow in Vimflowy. 
                How to use:
                <ul>
                    <li> Create a node anywhere with "GTD" text in it and started adding your gtd tags.</li>
                    <li> Adding tags like #today, #next, #soon gets automatically cloned in 
                        GTD node with their topics on calling the trigger keyboard shortcut. </li>
                </ul>
            </div>
        ),
    },
    async (api) => {
        const gtdHelper = new GtdHelperPlugin(api);
        return gtdHelper;
    },
    (api => api.deregisterAll()),
);
