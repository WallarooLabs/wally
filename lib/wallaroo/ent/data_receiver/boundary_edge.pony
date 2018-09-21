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

class val BoundaryEdge is Equatable[BoundaryEdge]
  let input_id: RoutingId
  let output_id: RoutingId

  new val create(i: RoutingId, o: RoutingId) =>
    input_id = i
    output_id = o

  fun eq(that: box->BoundaryEdge): Bool =>
    (input_id == that.input_id) and (output_id == that.output_id)

  fun hash(): USize =>
    input_id.hash() xor output_id.hash()

