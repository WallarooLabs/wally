use "wallaroo/topology"

use @w_computation_compute[DataP](computation: ComputationP, input: DataP)
use @w_computation_get_name[Pointer[U8]](computation: ComputationP)

use @w_state_computation_compute[DataP](state_computation: StateComputationP, input: DataP, state: StateP)
use @w_state_computation_get_name[Pointer[U8]](state_computation: StateComputationP)

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

class CPPStateComputation is StateComputation[CPPData val, CPPData val, CPPState val]
  let _computation: CPPManagedObject val
  let _name: String

  new create(computation: CPPManagedObject val) =>
    _computation = computation
    _name = recover String.from_cstring(@w_state_computation_get_name(_computation.obj())) end

  fun apply(input: CPPData val, state: CPPState val): (CPPData val | None) =>
    match @w_state_computation_compute(_computation.obj(), input.obj(), state.obj())
    | let result: DataP if (not result.is_null()) =>
      recover CPPData(CPPManagedObject(result)) end
    else
      None
    end

  fun name(): String =>
    _name