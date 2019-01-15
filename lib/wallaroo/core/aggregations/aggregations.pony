/*

Copyright 2018 The Wallaroo Authors.

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

use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo/core/windows"

interface val Aggregation[In: Any val, Out: Any val, Acc: State ref] is
  Computation[In, Out]
  // Create initial (empty/identity element for combine) accumulator
  fun initial_accumulator(): Acc

  // Take an input and add it to the aggregation.
  fun update(input: In, acc: Acc)

  // Combine 2 partial aggregations. Must be associative. This function
  // should not modify either accumulator when producing a new one.
  fun combine(acc1: Acc, acc2: Acc): Acc

  // Create an output based on an accumulator when the window is triggered.
  fun output(key: Key, window_end_ts: U64, acc: Acc): (Out | None)

  fun name(): String

  ////////////////////////////
  // Not implemented by user
  ////////////////////////////
  fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
    RunnerBuilder
  =>
    let global_window_initializer = GlobalWindowStateInitializer[In, Out, Acc](
      this)
    StateRunnerBuilder[In, Out, Acc](global_window_initializer, step_group_id,
      parallelization)

