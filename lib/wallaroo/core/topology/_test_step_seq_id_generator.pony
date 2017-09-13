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
use "wallaroo/core/common"
use "wallaroo/core/routing"

actor _TestStepSeqIdGenerator is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestNewIncrementsByOne)
    test(_TestLatestAfterNew)
    test(_TestLatestWithNew)
    test(_TestLatestWithoutNew)

class iso _TestNewIncrementsByOne is UnitTest
  """
  Verify that calling new_id() results in an increase of 1
  """
  fun name(): String =>
    "step_seq_id_generator/new_increments_by_one"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    gen.new_incoming_message()
    let x = gen.new_id()
    let y = gen.new_id()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId]((x + 1), y)

class iso _TestLatestAfterNew is UnitTest
  """
  Verify calling `latest_for_run` after `new_id` results in the same id.
  """
  fun name(): String =>
    "step_seq_id_generator/latest_after_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    gen.new_incoming_message()
    let x = gen.new_id()
    let y = gen.latest_for_run()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId](x, y)

class iso _TestLatestWithNew is UnitTest
  """
  Verify calling `latest_for_run` returns a new id when used in conjunction
  with a call to new. We do this by doing more than one "run" and verify that
  the ids are different.
  """
  fun name(): String =>
    "step_seq_id_generator/latest_without_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    gen.new_incoming_message()
    let x = gen.latest_for_run()
    gen.new_incoming_message()
    let y = gen.latest_for_run()

    h.assert_ne[SeqId](0, x)
    h.assert_true(x < y)

class iso _TestLatestWithoutNew is UnitTest
  """
  Verify calling `latest_for_run` doesn't return a new id when not used
  in conjunction with a call to new. We do this by doing more than one
  "run" and verify that the ids are the same.
  """
  fun name(): String =>
    "step_seq_id_generator/latest_without_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    gen.new_incoming_message()
    let x = gen.latest_for_run()
    let y = gen.latest_for_run()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId](x, y)
