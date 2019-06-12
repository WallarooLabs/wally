use "ponytest"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/registries"
use "wallaroo_labs/string_set"


actor MockKeyRegistry is KeyRegistry
  let _h: TestHelper
  let keys: KeySet = KeySet

  new create(h: TestHelper) =>
    _h = h

  be register_key(step_group: RoutingId, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    keys.set(key)

  be unregister_key(step_group: RoutingId, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    keys.unset(key)

  be has_key(k: Key) =>
    _h.assert_true(keys.contains(k))
    _h.complete(true)

  be does_not_have_key(k: Key) =>
    _h.assert_true(not keys.contains(k))
    _h.complete(true)

