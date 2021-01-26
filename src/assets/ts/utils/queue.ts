import { ExtendableError } from '../../../shared/utils/errors';

export class QueueStoppedError extends ExtendableError {
  constructor(m = '', name = 'QueueStoppedError') {
    super(m ? `Queue stopped: ${m}!` : 'Queue stopped!', name);
  }
}

// Simple queue class where you can
// enqueue synchronously, and dequeue asynchronously
// (waiting for the next enqueue if nothing is available)
export default class Queue<T> {
  private queue: Array<T>;
  private resolveNext: ((val: T) => void) | null;
  private nextProm: Promise<T> | null;
  private id: number;
  private stopped: boolean;

  constructor(vals: Array<T> = []) {
    this.queue = [];
    this.resolveNext = null;
    this.nextProm = null;
    vals.forEach((val) => this.enqueue(val));
    this.id = Math.random();
    this.stopped = false;
  }

  public empty() {
    return this.queue.length === 0;
  }

  public stop() {
    this.stopped = true;
  }

  public dequeue(): Promise<T> {
    if (!this.empty()) {
      const val = this.queue.shift();
      if (val === undefined) {
        throw new Error('Unexpected empty queue');
      }
      return Promise.resolve(val);
    }
    if (this.stopped) {
      throw new QueueStoppedError('queue is stopped!');
    }

    if (this.nextProm != null) {
      throw new Error('Cannot have multiple waiting on queue');
      // return this.nextProm;
    }
    this.nextProm = new Promise((resolve) => {
      let real_resolve = (val: T) => {
        resolve(val);
      };
      this.resolveNext = real_resolve;
    });
    return this.nextProm;
  }

  public enqueue(val: T) {
    if (this.stopped) {
      throw new QueueStoppedError('queue is stopped, cannot enqueue!');
    }
    if (this.resolveNext != null) {
      this.resolveNext(val);
      this.nextProm = null;
      this.resolveNext = null;
      return true;
    } else {
      this.queue.push(val);
      return false;
    }
  }
}
