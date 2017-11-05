use "serialise"
use "wallaroo/core/state"
use "wallaroo_labs/mort"

class GoState is State
  var _state_id: U64

  new create(state_id: U64) =>
    _state_id = state_id

  fun id(): U64 val =>
    _state_id

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_state_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_state_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_state_id)
