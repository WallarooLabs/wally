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

use "wallaroo/state"

export CPPStateChangeRepositoryHelper

primitive CPPStateChangeRepositoryHelper
  fun lookup_by_name(sc_repo: StateChangeRepository[CPPState],
    name_p: Pointer[U8] val): (StateChange[CPPState] | None)
  =>
    let name = recover val
      String.copy_cstring(name_p, @strlen[USize](name_p))
    end

    try
      ((sc_repo as StateChangeRepository[CPPState])
        .lookup_by_name(name) as CPPStateChange)
    else
      None
    end

  fun get_state_change_object(state_change: CPPStateChange): Pointer[U8] val =>
    state_change.obj()

  fun get_stateful_computation_return(data: Pointer[U8] val,
    state_change: (CPPStateChange | None)):
    CPPStateComputationReturnPairWrapper ref
  =>
    let d = if data.is_null() then
      None
    else
      recover val CPPData(data) end
    end

    CPPStateComputationReturnPairWrapper(d, state_change)
