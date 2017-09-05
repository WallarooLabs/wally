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

use "random"
use "time"

class GuidGenerator
  let _rand: Random

  new create(seed: U64 = Time.nanos()) =>
    _rand = MT(seed)

  fun ref apply(): U64 =>
    _rand.next()

  fun ref u128(): U128 =>
    _rand.next().u128() or (_rand.next().u128() << 64)

  fun ref u64(): U64 =>
    _rand.next()
