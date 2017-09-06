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

use "time"

primitive WallClock
  fun nanoseconds(): U64 =>
    let wall = Time.now()
    ((wall._1 * 1000000000) + wall._2).u64()

  fun microseconds(): U64 =>
    let wall = Time.now()
    ((wall._1 * 1000000) + (wall._2/1000)).u64()

  fun milliseconds(): U64 =>
    let wall = Time.now()
    ((wall._1 * 1000) + (wall._2/1000000)).u64()

  fun seconds(): U64 =>
    let wall = Time.now()
    wall._1.u64()
