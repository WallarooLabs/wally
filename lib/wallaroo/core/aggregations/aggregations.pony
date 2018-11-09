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

use "wallaroo/state"

interface Aggregation[In: Any val, Out: Any val, Acc: State] is
  Computation[In, Out]
  // Create initial (empty/identity element for combine) accumulator
  fun initial_accumulator(): Acc

  // Take an input and add it to the aggregation.
  fun update(input: In, acc: Acc)

  // Combine 2 partial aggregations. Must be associative. This function
  // should not modify either accumulator when producing a new one.
  fun combine(acc1: Acc box, acc2: Acc box): Acc

  // Create an output based on an accumulator when the window is triggered.
  fun output(key: Key, acc: Acc): Out

  // fun val runner_builder(step_group_id: RoutingId, parallelization: USize):
  //   RunnerBuilder
  // =>
  //   StateRunnerBuilder[In, Out, S](this, step_group_id, parallelization)
