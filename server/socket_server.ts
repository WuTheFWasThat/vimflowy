import * as http from 'http';

import * as WebSocket from 'ws';

import DataBackend, { InMemory } from '../src/shared/data_backend';
import logger from '../src/shared/utils/logger';

import { SQLiteBackend } from './data_backends';

type SocketServerOptions = {
  db?: string,
  dbfolder?: string,
  password?: string,
  path?: string,
};

export default function makeSocketServer(server: http.Server, options: SocketServerOptions) {
  const wss = new WebSocket.Server({ server, path: options.path });

  const dbs: {[docname: string]: DataBackend} = {};
  const clients: {[docname: string]: string} = {};

  async function getBackend(docname: string): Promise<DataBackend> {
    if (docname in dbs) {
      return dbs[docname];
    }
    let db: DataBackend;
    if (options.db === 'sqlite') {
      let filename;
      if (options.dbfolder) {
        filename = `${options.dbfolder}/${docname || 'vimflowy'}.sqlite`;
        logger.info('Using sqlite database: ', filename);
      } else {
        filename = ':memory:';
        logger.warn('Using in-memory sqlite database');
      }
      const sql_db = new SQLiteBackend();
      await sql_db.init(filename);
      db = sql_db;
    } else {
      logger.info('Using in-memory database');
      db = new InMemory();
    }
    dbs[docname] = db;
    return db;
  }

  function broadcast(message: Object): void {
    wss.clients.forEach(client => {
      client.send(JSON.stringify(message));
    });
  }

  wss.on('connection', function connection(ws) {
    logger.info('New socket connection!');
    let authed = false;
    let docname: string | null = null;
    ws.on('message', async (msg_string) => {
      logger.debug('received message: %s', msg_string);
      const msg = JSON.parse(msg_string);

      function respond(result: { value?: any, error: string | null }) {
        ws.send(JSON.stringify({
          type: 'callback',
          id: msg.id,
          result: result,
        }));
      }

      if (msg.type === 'join') {
        if (options.password) {
          if (msg.password !== options.password) {
            return respond({ error: 'Wrong password!' });
          }
        }
        authed = true;
        docname = msg.docname;
        clients[msg.docname] = msg.clientId;
        // TODO: only broadcast to client on this document?
        broadcast({
          type: 'joined',
          clientId: msg.clientId,
          docname: msg.docname,
        });
        return respond({ error: null });
      }

      if (!authed) {
        return respond({ error: 'Not authenticated!' });
      }
      if (docname == null) {
        throw new Error('No docname!');
      }
      if (msg.clientId !== clients[docname]) {
        return respond({ error: 'Other client connected!' });
      }
      const db = await getBackend(docname);

      if (msg.type === 'get') {
        const value = await db.get(msg.key);
        logger.debug('got', msg.key, value);
        respond({ value: value, error: null });
      } else if (msg.type === 'set') {
        await db.set(msg.key, msg.value);
        logger.debug('set', msg.key, msg.value);
        respond({ error: null });
      }
    });

    ws.on('close', () => {
      logger.info('Socket connection closed!');
      // TODO: clean up stuff?
    });
  });
  return server;
}
