import * as minimist from 'minimist';

import { buildProd } from './build_utils';

async function main(_args: any) {
  await buildProd();
}

main(minimist(process.argv.slice(2)));
