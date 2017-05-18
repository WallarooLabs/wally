use "wallaroo/state"

use @w_state_change_builder_build[StateChangeP]
  (builder_function: Pointer[U8] val, id: U64)

type StateChangeBuilderP is Pointer[U8] val

class CPPStateChangeBuilder is StateChangeBuilder[CPPState]
  var _state_change_builder: StateChangeBuilderP

  new create(state_change_builder: StateChangeBuilderP) =>
    _state_change_builder = state_change_builder

  fun apply(id: U64): CPPStateChange =>
    CPPStateChange(recover
      @w_state_change_builder_build(_state_change_builder, id)
    end)

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_state_change_builder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_state_change_builder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state_change_builder = recover
      @w_user_serializable_deserialize(bytes)
    end

  fun _final() =>
    @w_managed_object_delete(_state_change_builder)
