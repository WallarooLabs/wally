type StateP is Pointer[U8] val

class CPPState
  let _state: StateP

  new create(state: StateP) =>
    _state = state

  fun obj(): StateP =>
    _state

  fun _final() =>
    @w_managed_object_delete(_state)
