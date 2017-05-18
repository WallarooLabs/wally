use "wallaroo/state"

// these are included because of sendence/wallaroo issue #814
use "serialise"
use "wallaroo/fail"

type StateP is Pointer[U8] val

class CPPState is State
  var _state: StateP

  new create(state: StateP) =>
    _state = state

  fun obj(): StateP =>
    _state

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_state)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_state, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state = recover @w_user_serializable_deserialize(bytes) end

  fun _final() =>
    @w_managed_object_delete(_state)
