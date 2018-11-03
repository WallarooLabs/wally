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

use "files"
use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    _TestMessageDeduplicator.make().tests(test)
    test(_TestEventLogDummyCreation)
    test(_TestHexOffset)
    test(_TestFilterLogFiles)

class _TestEventLogDummyCreation is UnitTest
  """
  """
  fun name(): String =>
    "recovery/EventLogDummyCreation"

  fun ref apply(h: TestHelper) ? =>
    let auth = h.env.root as AmbientAuth

    // Create an event log without a config (gets a DummyBackend)
    let el_no_conf = EventLog(auth, "w1", SimpleJournalNoop)

class _TestHexOffset is UnitTest
  fun name(): String =>
      "recovery/HexOffset"

  fun ref apply(h: TestHelper) ? =>
    let u: U64 = 100186
    let expected: String = "000000000001875A"
    let hex: String = HexOffset(u)
    let s: String val = consume hex
    let hex_decoded: U64 = HexOffset.u64(s)?
    h.assert_eq[String](expected, s)
    h.assert_eq[U64](u, hex_decoded)

class _TestFilterLogFiles is UnitTest
  fun name(): String =>
    "recovery/FilterLogFiles"

  fun ref apply(h: TestHelper) ? =>
    let dir_files: Array[String] iso = recover
      let a: Array[String] = Array[String]
      a.push("app-worker1-000000000001875A.evlog")
      a.push("app-worker1-0000000000000000.evlog")
      a.push("app-worker2-000000000001876A.evlog")
      a.push("app-worker1-0000000000011111.evlog")
      a.push("app-worker3-000000000000900B.evlog")
      a.push("app-worker1-00000000006DF0A1.evlog")
      a.push("app-worker2-0000000000000000.evlog")
      a.push("app-worker3-0000000000000000.evlog")
      a.push("app-worker4-0000000000000000.evlog")
      consume a
    end

    let base_name: String = "app-worker1"
    let suffix: String = ".evlog"
    let expected: Array[String] = expected.create()
    expected.push("app-worker1-0000000000000000.evlog")
    expected.push("app-worker1-0000000000011111.evlog")
    expected.push("app-worker1-000000000001875A.evlog")
    expected.push("app-worker1-00000000006DF0A1.evlog")

    let filtered = FilterLogFiles(base_name, suffix, consume dir_files)

    for idx in filtered.keys() do
      h.assert_eq[String](filtered(idx)?, expected(idx)?)
    end
