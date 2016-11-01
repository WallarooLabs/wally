use "collections"
use "wallaroo/topology"

use @w_computation_compute[DataP](computation: ComputationP, input: DataP)
use @w_computation_get_name[Pointer[U8]](computation: ComputationP)

use @w_state_computation_compute[StateComputationReturn](state_computation: StateComputationP,
  input: DataP,sc_repo: StateChangeRepository[CPPState], state: StateP, n: None)
use @w_state_computation_get_name[Pointer[U8]](state_computation: StateComputationP)
use @w_state_computation_get_number_of_state_change_builders[USize](state_computaton: StateComputationP)
use @w_state_computation_get_state_change_builder[StateChangeBuilderP](state_computation: StateComputationP, idx: USize)

type ComputationP is ManagedObjectP
type StateComputationP is ManagedObjectP

class CPPComputation is Computation[CPPData val, CPPData val]
  let _computation: CPPManagedObject val
  let _name: String

  new create(computation: CPPManagedObject val) =>
    _computation = computation
    _name = recover String.from_cstring(@w_computation_get_name(_computation.obj())) end

  fun apply(input: CPPData val): (CPPData val | None) =>
    match @w_computation_compute(_computation.obj(), input.obj())
    | let result: DataP if (not result.is_null()) =>
      recover CPPData(CPPManagedObject(result)) end
    else
      None
    end

  fun name(): String =>
    _name

struct StateComputationReturn
  let has_data: Bool = false
  embed data: Pointer[U8] val = recover Pointer[U8] end
  let has_state_change: Bool = false
  embed state_change: CPPStateChange = CPPStateChange(recover CPPManagedObject(recover Pointer[U8] end) end)

class CPPStateComputation is StateComputation[CPPData val, CPPData val, CPPState]
  let _computation: CPPManagedObject val
  let _name: String

  new create(computation: CPPManagedObject val) =>
    _computation = computation
    _name = recover String.from_cstring(@w_state_computation_get_name(_computation.obj())) end

  fun apply(input: CPPData val, sc_repo: StateChangeRepository[CPPState], state: CPPState):
    ((CPPData val | None), (CPPStateChange | None))
  =>
    let ret = @w_state_computation_compute(_computation.obj(), input.obj(), sc_repo, state.obj(), None)
    let rd = ret.data
    let ret_data: (CPPData val | None) = if ret.has_data then
      recover val CPPData(CPPManagedObject(rd)) end
    else
      None
    end

    let ret_state_change = if ret.has_state_change then
      ret.state_change
    else
      None
    end

    (ret_data, ret_state_change)

  fun name(): String =>
    _name

  fun state_change_builders(): Array[StateChangeBuilder[CPPState] val] val =>
    let num_builders = @w_state_computation_get_number_of_state_change_builders(_computation.obj())
    recover
      let builders = Array[StateChangeBuilder[CPPState] val](num_builders)
      for i in Range(0, num_builders) do
        builders.push(recover CPPStateChangeBuilder(recover CPPManagedObject(@w_state_computation_get_state_change_builder(_computation.obj(), i)) end) end)
      end
      builders
    end
