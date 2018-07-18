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

class BoundaryId is Equatable[BoundaryId]
  let name: String
  let step_id: RoutingId

  new create(n: String, s_id: RoutingId) =>
    name = n
    step_id = s_id

  fun eq(that: box->BoundaryId): Bool =>
    (name == that.name) and (step_id == that.step_id)

  fun hash(): USize =>
    name.hash() xor step_id.hash()
