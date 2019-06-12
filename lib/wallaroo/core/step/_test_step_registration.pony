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

use "collections"
use "ponytest"
use "promises"
use "random"
use "time"
use "wallaroo/core/aggregations"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"
use "wallaroo/test_components"


actor _TestStepRegistration is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_AtCreationStepRegistersAsProducerWithOneDownstream)
    test(_AtCreationStepRegistersAsProducerWithTwoDownstreams)

class iso _AtCreationStepRegistersAsProducerWithOneDownstream is UnitTest
  fun name(): String =>
    "step/registration/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let key = "key"
    let auth = h.env.root as AmbientAuth
    let expected_registered_count: USize = 1
    let oc = TestOutputCollector[USize](h where
      expected_registered_count = expected_registered_count,
      watch_for_success = true)

    // when
    let step = TestOutputCollectorStepBuilder[USize](h.env, auth, oc)

    // then
    // TestOutputCollector is set to watch for success

    h.long_test(1_000_000_000)

class iso _AtCreationStepRegistersAsProducerWithTwoDownstreams is UnitTest
  fun name(): String =>
    "step/registration/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let key = "key"
    let auth = h.env.root as AmbientAuth
    let expected_registered_count: USize = 1

    let p1 = Promise[None]
    let p2 = Promise[None]
    TestCompleteOnPromises(h, [p1; p2])

    let oc1 = TestOutputCollector[USize](h where
      expected_registered_count = expected_registered_count,
      completion_promise = p1, watch_for_success = true)
    let oc2 = TestOutputCollector[USize](h where
      expected_registered_count = expected_registered_count,
      completion_promise = p2, watch_for_success = true)

    // when
    let step = TestOutputCollectorStepBuilder[USize](h.env, auth, [oc1; oc2])

    // then
    // TestOutputCollectors are set to watch for success

    h.long_test(1_000_000_000)

