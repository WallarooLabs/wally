use "wallaroo/topology"

export CPPStateChangeRepositoryHelper

primitive CPPStateChangeRepositoryHelper
  fun lookup_by_name(sc_repo: StateChangeRepository[CPPState], name_p: Pointer[U8] val): (StateChange[CPPState] | None) =>
    let name = recover val String.copy_cstring(name_p, @strlen[USize](name_p)) end
    try
      ((sc_repo as StateChangeRepository[CPPState]).lookup_by_name(name) as CPPStateChange)
    else
      None
    end

  fun get_state_change_object(state_change: CPPStateChange): Pointer[U8] val =>
    state_change.obj()

  fun get_stateful_computation_return(data: Pointer[U8] val, state_change: (CPPStateChange | None)):
    ((CPPData val | None), (CPPStateChange | None))
  =>
    let d = if data.is_null() then
      None
    else
      recover val CPPData(recover CPPManagedObject(data) end) end
    end

    (d, state_change)
