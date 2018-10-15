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

use "random"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"


trait Grouper
  fun ref apply[D: Any val](d: D): Key

class OneToOneGrouper is Grouper
  fun ref apply[D: Any val](d: D): Key =>
    "one-to-one-grouping-key"

primitive Shuffle
  fun apply(): Shuffler =>
    Shuffler

class Shuffler is Grouper
  let _rand: Random

  new create(seed: U64 = Time.nanos()) =>
    _rand = MT(seed)

  fun ref apply[D: Any val](d: D): Key =>
    _rand.next().string()

trait val GroupByKey
  fun apply(): KeyGrouper

class val TypedGroupByKey[In: Any val] is GroupByKey
  let key_extractor: KeyExtractor[In]

  new val create(ke: KeyExtractor[In]) =>
    key_extractor = ke

  fun apply(): KeyGrouper =>
    TypedKeyGrouper[In](key_extractor)

trait KeyGrouper is Grouper
  fun ref apply[D: Any val](d: D): Key

class TypedKeyGrouper[In: Any val] is KeyGrouper
  let key_extractor: KeyExtractor[In]

  new create(ke: KeyExtractor[In]) =>
    key_extractor = ke

  fun ref apply[D: Any val](d: D): Key =>
    match d
    | let i: In =>
      key_extractor(i)
    else
      Fail()
      ""
    end
