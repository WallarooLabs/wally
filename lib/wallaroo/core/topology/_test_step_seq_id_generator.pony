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
    test(_TestCurrentAfterNew)
    test(_TestCurrentWithoutNew)
    test(_TestCurrentWithNew)
    test(_TestCurrentDoesNotIncrement)

class iso _TestNewIncrementsByOne is UnitTest
  """
  Verify that calling new_id() results in an increase of 1
  """
  fun name(): String =>
    "step_seq_id_generator/new_increments_by_one"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator
    let x = gen.new_id()
    let y = gen.new_id()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId]((x + 1), y)

class iso _TestCurrentAfterNew is UnitTest
  """
  Verify calling `current_seq_id` after `new_id` results in the same id.
  """
  fun name(): String =>
    "step_seq_id_generator/current_after_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    let x = gen.new_id()
    let y = gen.current_seq_id()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId](x, y)

class iso _TestCurrentDoesNotIncrement is UnitTest
  """
  `current_seq_id()` will not increment the id value, even
  if the generator has never had `new_id()` called on it before.
  """
  fun name(): String =>
    "step_seq_id_generator/current_doesnt_increment"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    h.assert_eq[SeqId](0,gen.current_seq_id())


class iso _TestCurrentWithoutNew is UnitTest
  """
  Verify calling `current_seq_id()` doesn't return a new id when not used
  in conjunction with a call to new. We do this by doing more than one
  "run" and verify that the ids are the same.
  """
  fun name(): String =>
    "step_seq_id_generator/current_without_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    let x = gen.current_seq_id()
    let y = gen.current_seq_id()

    h.assert_eq[SeqId](x, y)


class iso _TestCurrentWithNew is UnitTest
  """
  Verify calling `current_seq_id()` returns the freshest id generated with
  `new_id`.
  """
  fun name(): String =>
    "step_seq_id_generator/current_with_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    let x = gen.new_id()
    let x_current = gen.current_seq_id()

    let y = gen.new_id()
    let y_current = gen.current_seq_id()

    h.assert_ne[SeqId](x, 0)
    h.assert_ne[SeqId](y, 0)
    h.assert_ne[SeqId](x, y)

    h.assert_eq[SeqId](x, x_current)
    h.assert_eq[SeqId](y, y_current)
