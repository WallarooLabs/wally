/*

Copyright 2019 The Wallaroo Authors.

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
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/core/state"
use "wallaroo/test_components"
use "wallaroo_labs/time"


actor _StateRunnerTests is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_KeyIsAddedWhenFirstMessageForKeyIsReceived)
    test(_KeyIsRemovedWhenStateIsRemoved)
    test(_KeyIsAddedWhenMessageForKeyIsReceivedAfterStateWasRemoved)

class iso _KeyIsAddedWhenFirstMessageForKeyIsReceived is UnitTest
  fun name(): String =>
    "topology/state_runner/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let auth = h.env.root as AmbientAuth
    let key = "key"
    let router = DirectRouter(0, DummyConsumer)
    let consumer_sender = MockConsumerSender[USize](h)
    let mock_state_init = MockStateInitializer[USize](h, auth)
    let mock_key_registry = MockKeyRegistry(h)
    let state_runner = mock_state_init.create_runner(where
      key_registry = mock_key_registry)

    // StateRunner[USize, USize, Array[USize]](
    //   0/*RoutingId*/, mock_state_init, mock_key_registry
    //   _EventLogDummyBuilder(auth), auth, consume mock_runner, false)

    // when
    TestRunnerSender[USize].send(1, key, state_runner, router, consumer_sender)

    // then
    mock_key_registry.has_key(key)

    h.long_test(1_000_000_000)

class iso _KeyIsRemovedWhenStateIsRemoved is UnitTest
  fun name(): String =>
    "topology/state_runner/"  + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let auth = h.env.root as AmbientAuth
    let key = "key"
    let router = DirectRouter(0, DummyConsumer)
    let consumer_sender = MockConsumerSender[USize](h)
    let mock_state_init = MockStateInitializer[USize](h, auth where
      lifetime = 2)
    let mock_key_registry = MockKeyRegistry(h)
    let state_runner = mock_state_init.create_runner(where
      key_registry = mock_key_registry)
    TestRunnerSender[USize].send(1, key, state_runner, router, consumer_sender)

    // when
    // Because state lifetime is 2, this should trigger key removal.
    TestRunnerSender[USize].send(2, key, state_runner, router, consumer_sender)

    // then
    mock_key_registry.does_not_have_key(key)

    h.long_test(1_000_000_000)


class iso _KeyIsAddedWhenMessageForKeyIsReceivedAfterStateWasRemoved
  is UnitTest
  fun name(): String =>
    "topology/state_runner/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let auth = h.env.root as AmbientAuth
    let key = "key"
    let router = DirectRouter(0, DummyConsumer)
    let consumer_sender = MockConsumerSender[USize](h)
    let mock_state_init = MockStateInitializer[USize](h, auth where
      lifetime = 2)
    let mock_key_registry = MockKeyRegistry(h)
    let state_runner = mock_state_init.create_runner(where
      key_registry = mock_key_registry)
    TestRunnerSender[USize].send(1, key, state_runner, router, consumer_sender)
    // Because state lifetime is 2, this should trigger key removal.
    TestRunnerSender[USize].send(2, key, state_runner, router, consumer_sender)

    // when
    TestRunnerSender[USize].send(3, key, state_runner, router, consumer_sender)

    // then
    mock_key_registry.has_key(key)

    h.long_test(1_000_000_000)
