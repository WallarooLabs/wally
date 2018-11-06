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

use "buffered"
use "collections"
use "time"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/routing"
use "wallaroo/core/state"


interface val Computation[In: Any val, Out: Any val]
  fun name(): String
  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder

interface val StatelessComputation[In: Any val, Out: Any val] is
  Computation[In, Out]
  fun apply(input: In): (Out | Array[Out] val | None)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StatelessComputationRunnerBuilder[In, Out](this, step_group_id,
      parallelization)

interface val StateComputation[In: Any val, Out: Any val, S: State ref] is
  Computation[In, Out]
  // Return a tuple containing the result of the computation (which is None
  // if there is no value to forward) and a StateChange if there was one (or
  // None to indicate no state change).
  fun apply(input: In, state: S): (Out | Array[Out] val | None)

  fun initial_state(): S

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    StateRunnerBuilder[In, Out, S](this, step_group_id, parallelization)

