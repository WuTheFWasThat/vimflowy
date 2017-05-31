import * as http from 'http';

import * as WebSocket from 'ws';

import DataBackend, * as dataBackends from '../assets/ts/data_backend';
import logger from '../assets/ts/utils/logger';

import * as serverBackends from './data_backends';

type SocketServerOptions = {
  db?: string,
  filename?: string,
  password?: string,
  path?: string,
};

export default async function makeSocketServer(server: http.Server, options: SocketServerOptions) {
  const wss = new WebSocket.Server({ server, path: options.path });
  let db: DataBackend;
  if (options.db === 'sqlite') {
    if (options.filename) {
      logger.info('Using sqlite database: ', options.filename);
    } else {
      logger.warn('Using in-memory sqlite database');
    }
    const sql_db = new serverBackends.SQLiteBackend();
    await sql_db.init(options.filename);
    db = sql_db;
  } else {
    logger.info('Using in-memory database');
    db = new dataBackends.InMemory();
  }

  function broadcast(message: Object): void {
    wss.clients.forEach(client => {
      client.send(JSON.stringify(message));
    });
  };

  let current_client: string | null;

  wss.on('connection', function connection(ws) {
    let authed = false;
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
        current_client = msg.clientId;
        broadcast({
          type: 'joined',
          clientId: msg.clientId,
        });
        return respond({ error: null });
      }

      if (!authed) {
        return respond({ error: 'Not authenticated!' });
      }
      if (msg.clientId !== current_client) {
        return respond({ error: 'Other client connected!' });
      }

      if (msg.type === 'get') {
        const value = await db.get(msg.key);
        logger.debug('got', msg.key, value);
        respond({ value: value, error: null })
      } else if (msg.type === 'set') {
        await db.set(msg.key, msg.value);
        logger.debug('set', msg.key, msg.value);
        respond({ error: null })
      }
    });
  });
  return server;
}
