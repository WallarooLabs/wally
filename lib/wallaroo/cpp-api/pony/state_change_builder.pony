use "wallaroo/topology"

use @w_state_change_builder_build[StateChangeP](builder_function: Pointer[U8] val, id: U64)

type StateChangeBuilderP is Pointer[U8] val

class CPPStateChangeBuilder is StateChangeBuilder[CPPState]
  let _state_change_builder: CPPManagedObject val

  new create(state_change_builder: CPPManagedObject val) =>
    _state_change_builder = state_change_builder

  fun apply(id: U64): CPPStateChange =>
    CPPStateChange(recover CPPManagedObject(@w_state_change_builder_build(_state_change_builder.obj(), id)) end)
