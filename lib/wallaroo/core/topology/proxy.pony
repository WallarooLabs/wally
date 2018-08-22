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

use "wallaroo/core/common"

class val ProxyAddress
  let worker: WorkerName
  let routing_id: RoutingId

  new val create(w: WorkerName, r_id: RoutingId) =>
    worker = w
    routing_id = r_id

  fun string(): String =>
    "[[" + worker + ": " + routing_id.string() + "]]"

  fun eq(that: box->ProxyAddress): Bool =>
    (worker == that.worker) and (routing_id == that.routing_id)

  fun ne(that: box->ProxyAddress): Bool => not eq(that)

  fun hash(): USize =>
    worker.hash() xor routing_id.hash()
