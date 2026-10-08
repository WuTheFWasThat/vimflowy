import 'mocha';
import * as assert from 'assert';

import Path from '../../src/assets/ts/path';
import { ClientStore } from '../../src/assets/ts/datastore';
import { SynchronousInMemory } from '../../src/shared/data_backend';

describe('path ancestry', function() {
  it('loads the root from empty ancestry', function() {
    const path = Path.loadFromAncestry([]);

    assert.ok(path.is(Path.root()));
    assert.deepStrictEqual(path.getAncestry(), []);
  });

  it('preserves the ancestry array and row order', function() {
    const ancestry = [1, 3, 2];
    const path = Path.loadFromAncestry(ancestry);

    assert.deepStrictEqual(path.getAncestry(), [1, 3, 2]);
    assert.deepStrictEqual(ancestry, [1, 3, 2]);
  });

  it('can load the same ancestry more than once', function() {
    const ancestry = [2, 1, 4];
    const first = Path.loadFromAncestry(ancestry);
    const second = Path.loadFromAncestry(ancestry);

    assert.ok(first.is(second));
    assert.deepStrictEqual(second.getAncestry(), [2, 1, 4]);
  });

  it('can load frozen ancestry', function() {
    const ancestry = [1, 2, 3];
    Object.freeze(ancestry);

    assert.deepStrictEqual(Path.loadFromAncestry(ancestry).getAncestry(), [1, 2, 3]);
  });

  it('keeps the saved zoom path in the client settings cache', function() {
    const backend = new SynchronousInMemory();
    const writer = new ClientStore(backend, 'saved-zoom');
    writer.setLastViewRoot([3, 1, 2]);
    const reader = new ClientStore(backend, 'saved-zoom');

    const restored = Path.loadFromAncestry(reader.getLastViewRoot());

    assert.deepStrictEqual(restored.getAncestry(), [3, 1, 2]);
    assert.deepStrictEqual(reader.getLastViewRoot(), [3, 1, 2]);
    assert.ok(Path.loadFromAncestry(reader.getLastViewRoot()).is(restored));
  });
});
