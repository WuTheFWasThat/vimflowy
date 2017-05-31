import * as sqlite from 'sqlite3';

import DataBackend from '../assets/ts/data_backend';

export class SQLiteBackend extends DataBackend {
  private db: sqlite.Database;
  private setStatement: sqlite.Statement;
  private getStatement: sqlite.Statement;
  private searchStatement: sqlite.Statement;
  private tableName: string = 'vimflowy';

  constructor() {
    super();
  }

  public async init(filename: string): Promise<void> {
    await new Promise((resolve, reject) => {
      this.db = new sqlite.Database(filename, (err) => {
        if (err) { reject(err); } else { resolve(); }
      });
    });

    await new Promise((resolve, reject) => {
      this.db.run(
        `CREATE TABLE IF NOT EXISTS ${this.tableName} (id string PRIMARY KEY, value string)`,
        (err) => {
          if (err) { reject(err); } else { resolve(); }
        }
      );
    });

    this.getStatement = this.db.prepare(
      `SELECT value FROM ${this.tableName} WHERE id = (?)`
    );

    this.setStatement = this.db.prepare(
      `INSERT OR REPLACE INTO ${this.tableName} ("id", "value") VALUES (?, ?)`
    );

    this.searchStatement = this.db.prepare(
      `SELECT id FROM ${this.tableName} WHERE value LIKE ? and id LIKE '%:line' LIMIT ?`,
    );

    console.log('query', Date.now());
    await new Promise((resolve, reject) => {
      this.db.all(
        `SELECT id FROM ${this.tableName} WHERE value LIKE '%generate%' and id LIKE '%:line' LIMIT 10`,
        (err, result) => {
          console.log('err', err, result);
          if (err) { reject(err); } else { resolve(); }
        }
      );
    });
    console.log('end query', Date.now());

    console.log('query', Date.now());
    await new Promise((resolve, reject) => {
      this.searchStatement.all(
        ['%taking%latent%', 10],
        (err, result) => {
          console.log('err', err, result);
          if (err) { reject(err); } else { resolve(); }
        }
      );
    });
    console.log('end query', Date.now());
  }

  public async get(key: string): Promise<string | null> {
    return await new Promise<string | null>((resolve, reject) => {
      this.getStatement.get([key], (err: string, result: any) => {
        if (err) { return reject(err); }
        if (!result) {
          resolve(null);
        } else {
          resolve(result.value);
        }
      });
    });
  }

  public async set(key: string, value: string): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      this.setStatement.run([key, value], (err: string) => {
        if (err) { return reject(err); }
        resolve();
      });
    });
  }
}
