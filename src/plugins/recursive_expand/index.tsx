import * as _ from 'lodash';

import { registerPlugin } from '../../assets/ts/plugins';
import Session from '../../assets/ts/session';
import logger from '../../shared/utils/logger';
import Path from '../../assets/ts/path';

export const pluginName = 'Recursive-Expand';

registerPlugin(
    {
        name: pluginName,
        author: 'Nikhil Sonti',
        description: `Lets you recursively expand or collapse a node`,
    },
    function (api) {

        async function toggleRecursiveCollapse(session: Session, path: Path, collapse: boolean) {
            logger.debug('Toggle state: ' + collapse + ' row = ' + path.row);
            await session.document.setCollapsed(path.row, collapse);

            if (await session.document.hasChildren(path.row)) {
                let children = await session.document.getChildren(path);
                logger.debug('No of children: ' + children.length);

                children.forEach(async (child_path) => {
                    await toggleRecursiveCollapse(session, child_path, collapse);
                });
            }
        }

        api.registerAction(
            'toggle-expand',
            'Toggle expand/collapse recursively',
            async function ({ session }) {
                let is_collapsed = await session.document.collapsed(session.cursor.row);
                await toggleRecursiveCollapse(session, session.cursor.path, !is_collapsed);
                await session.document.forceLoadTree(session.cursor.row, false);
            },
        );

        api.registerDefaultMappings(
            'NORMAL',
            {
                'toggle-expand': [['Z']],
            },
        );
    },
    (api => api.deregisterAll()),
);
