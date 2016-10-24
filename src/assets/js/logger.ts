/*
A straightforward class for configurable logging
Log-levels and streams (currently only one stream at a time)
*/

export enum LEVEL {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  FATAL = 4,
}

const LEVELS = [
  'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL',
];

export enum STREAM {
  STDOUT,
  STDERR,
  QUEUE,
};

export class Logger {
  private stream: STREAM;
  private level: LEVEL;
  private queue: Array<any>;

  // hack since we add the methods dynamically
  public info: any;
  public debug: any;
  public warn: any;
  public error: any;
  public fatal: any;

  constructor(level = LEVEL.INFO, stream = STREAM.STDOUT) {
    this.setLevel(level);
    this.setStream(stream);

    const register_loglevel = (name, value) => {
      return this[name.toLowerCase()] = function() {
        if (this.level <= value) {
          return this.log.apply(this, arguments);
        }
      };
    };

    LEVELS.forEach((name) => {
      const value = LEVEL[name];
      register_loglevel(name, value);
    });
  }

  // tslint:disable-next-line no-unused-variable
  private log() {
    if (this.stream === STREAM.STDOUT) {
      return console.log.apply(console, arguments);
    } else if (this.stream === STREAM.STDERR) {
      return console.error.apply(console, arguments);
    } else if (this.stream === STREAM.QUEUE) {
      return this.queue.push(arguments);
    }
  }

  public setLevel(level) {
    this.level = level;
  }

  public off() {
    this.level = Infinity;
  }

  public setStream(stream) {
    this.stream = stream;
    if (this.stream === STREAM.QUEUE) {
      this.queue = [];
    }
  }

  // for queue

  public flush() {
    if (this.stream === STREAM.QUEUE) {
      this.queue.forEach((args) => {
        console.log.apply(console, args);
      });
      return this.empty();
    }
  }

  public empty() {
    this.queue = [];
  }
}

const logger = new Logger(LEVEL.INFO);
export default logger;
