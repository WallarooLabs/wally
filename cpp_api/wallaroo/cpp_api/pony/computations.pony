/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"
use "wallaroo/core/topology"
use "wallaroo/core/state"
use "wallaroo_labs/mort"

use @w_computation_compute[DataP](computation: ComputationP, input: DataP)
use @w_computation_get_name[Pointer[U8]](computation: ComputationP)
use @w_state_computation_compute[CPPStateComputationReturnPairWrapper ref]
  (state_computation: StateComputationP, input: DataP,
  sc_repo: StateChangeRepository[CPPState],
  sc_repo_helper: CPPStateChangeRepositoryHelper, state: StateP, n: None)
use @w_state_computation_get_name[Pointer[U8]]
  (state_computation: StateComputationP)
use @w_state_computation_get_number_of_state_change_builders[USize]
  (state_computaton: StateComputationP)
use @w_state_computation_get_state_change_builder[StateChangeBuilderP]
  (state_computation: StateComputationP, idx: USize)

type ComputationP is Pointer[U8] val
type StateComputationP is Pointer[U8] val

class CPPComputation is Computation[CPPData val, CPPData val]
  var _computation: ComputationP

  new create(computation: ComputationP) =>
    _computation = computation

  fun apply(input: CPPData val): (CPPData val | None) =>
    let ret = match @w_computation_compute(_computation, input.obj())
    | let result: DataP =>
      if input.obj() == result then
        @printf[I32]("returning the same object is not allowed\n".string())
      end
      if (not result.is_null()) then
        recover CPPData(result) end
      else
        None
      end
    else
      @printf[I32]("result is not a DataP".cstring())
      None
    end
    ret

  fun name(): String =>
    recover String.from_cstring(@w_computation_get_name(_computation)) end

  fun _final() =>
    @w_managed_object_delete(_computation)

class CPPStateComputationReturnPairWrapper
  let data: (CPPData val | None)
  let change: (CPPStateChange ref | None)
  fun ref get_tuple(): ((CPPData val | None), (CPPStateChange ref | None)) =>
    (data, change)
  new create(data': (CPPData val |None), change': (CPPStateChange ref | None)) =>
    data = data'
    change = change'

class CPPStateComputation is StateComputation[CPPData val, CPPData val, CPPState]
  var _computation: StateComputationP

  new create(computation: StateComputationP) =>
    _computation = computation

  fun apply(input: CPPData val,
    sc_repo: StateChangeRepository[CPPState], state: CPPState):
    ((CPPData val | None), (CPPStateChange | None))
  =>
    let result_p = @w_state_computation_compute(_computation, input.obj(), sc_repo,
      CPPStateChangeRepositoryHelper, state.obj(), None)

    let result = result_p.get_tuple()

    match result._1
    | let r: CPPData val =>
      if input.obj() == r.obj() then
        @printf[I32]("returning the same object is not allowed".cstring())
      end
    end

    result

  fun name(): String =>
    recover String.from_cstring(@w_state_computation_get_name(_computation)) end

  fun state_change_builders(): Array[StateChangeBuilder[CPPState] val] val =>
    let num_builders =
      @w_state_computation_get_number_of_state_change_builders(_computation)

    recover
      let builders = Array[StateChangeBuilder[CPPState] val](num_builders)
      for i in Range(0, num_builders) do
        builders.push(recover
          CPPStateChangeBuilder(
            @w_state_computation_get_state_change_builder(_computation, i))
        end)
      end
      builders
    end

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_computation)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_computation, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation = recover @w_user_serializable_deserialize(bytes) end

  fun _final() =>
    @w_managed_object_delete(_computation)
