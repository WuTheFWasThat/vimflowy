// Simple queue class where you can
// enqueue synchronously, and dequeue asynchronously
// (waiting for the next enqueue if nothing is available)
export default class Queue<T> {
  private queue: Array<T>;
  private resolveNext: ((val: T) => void) | null;
  private nextProm: Promise<T> | null;

  constructor(vals: Array<T> = []) {
    this.queue = [];
    this.resolveNext = null;
    this.nextProm = null;
    vals.forEach((val) => this.enqueue(val));
  }

  public empty() {
    return this.queue.length === 0;
  }

  public dequeue(): Promise<T> {
    if (!this.empty()) {
      const val = this.queue.shift();
      return Promise.resolve(val);
    }

    if (this.nextProm != null) {
      throw new Error('Cannot have multiple waiting on queue');
      // return this.nextProm;
    }
    this.nextProm = new Promise((resolve) => {
      this.resolveNext = resolve;
    });
    return this.nextProm;
  }

  public enqueue(val: T) {
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
