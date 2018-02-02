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

use "ponytest"
use "collections"
use "debug"
use "../collection_helpers"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestEncodeDecodeState)

class iso _TestEncodeDecodeState is UnitTest
  fun name(): String => "query_json/encode_decode_state"

  fun apply(h: TestHelper) ? =>
    let m = recover iso Map[String, Map[String, Array[String] val]] end
    var submap = recover iso Map[String, Array[String] val] end
    let a1 = recover val ["1"] end
    let a2 = recover val ["12";"23"] end
    let a3 = recover val ["1";"2";"3"] end
    let a4 = recover val ["134";"234";"334";"434"] end
    let a5 = recover val ["3";"6";"9";"12";"15"] end
    let a6 = recover val ["20";"40";"60";"80";"100"] end

    let k1 = "key1"
    let k2 = "key2"
    let k3 = "third_key"
    let k4 = "sleutel_vier"

    let w1 = "w1"
    let w2 = "worker2"
    let w3 = "initializer"

    submap(w1) = a1
    submap(w2) = a4
    submap(w3) = a6
    m(k1) = (submap = recover iso Map[String, Array[String] val] end)

    submap(w1) = a2
    submap(w2) = a3
    submap(w3) = a5
    m(k2) = (submap = recover iso Map[String, Array[String] val] end)

    submap(w1) = a1
    submap(w2) = a6
    submap(w3) = a2
    m(k3) = (submap = recover iso Map[String, Array[String] val] end)

    submap(w1) = a2
    submap(w2) = a4
    submap(w3) = a5
    m(k4) = (submap = recover iso Map[String, Array[String] val] end)

    let prep_map =
      recover iso Map[String, Map[String, Array[String] val] val] end
    for (k, v) in (consume val m).pairs() do
      let prep_submap = recover iso Map[String, Array[String] val] end
      for (subk, subv) in v.pairs() do
        prep_submap(subk) = subv
      end
      prep_map(k) = consume prep_submap
    end

    let map_val = consume val prep_map

    let json = PartitionQueryEncoder.partitions(map_val)

    let new_map = PartitionQueryDecoder.partitions(json)

    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k1)?(w1)?,
      new_map(k1)?(w1)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k1)?(w2)?,
      new_map(k1)?(w2)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k1)?(w3)?,
      new_map(k1)?(w3)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k2)?(w1)?,
      new_map(k2)?(w1)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k2)?(w2)?,
      new_map(k2)?(w2)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k2)?(w3)?,
      new_map(k2)?(w3)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k3)?(w1)?,
      new_map(k3)?(w1)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k3)?(w2)?,
      new_map(k3)?(w2)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k3)?(w3)?,
      new_map(k3)?(w3)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k4)?(w1)?,
      new_map(k4)?(w1)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k4)?(w2)?,
      new_map(k4)?(w2)?))
    h.assert_eq[Bool](true, ArrayHelpers[String].eq[String](map_val(k4)?(w3)?,
      new_map(k4)?(w3)?))
