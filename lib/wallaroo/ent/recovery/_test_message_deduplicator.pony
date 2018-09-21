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

use "ponytest"
use "wallaroo/core/common"

actor _TestMessageDeduplicator is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestEmptyDuplicates)
    test(_TestDifferentMessagesNoFracs)
    test(_TestDifferentMessagesSameFracs)
    test(_TestSameMessageNoFracs)
    test(_TestSameMessageDifferentFracs)
    test(_TestSameMessageDifferentFracs2)
    test(_TestSameMessageDifferentFracs3)
    test(_TestSameMessageDifferentFracs4)
    test(_TestSameMessageSameFracs)
    test(_TestMatchIsLater)
    test(_TestMatchIsLater2)
    test(_TestMatchIsLater3)

class _TestEmptyDuplicates is UnitTest
  fun name(): String =>
    "message_deduplicator/EmptyDuplicates"

  fun ref apply(h: TestHelper) =>
    let empty = DeduplicationList.create()
    let is_dup = MessageDeduplicator.is_duplicate(1, None, empty)

    h.assert_eq[Bool](false, is_dup)

class _TestDifferentMessagesNoFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/DifferentMessagesNoFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), None) )

    let msg_id = MsgId(2)
    let frac_ids = None

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestDifferentMessagesSameFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/DifferentMessagesSameFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [1] end) )

    let msg_id = MsgId(2)
    let frac_ids = recover val [as U32: 1] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageNoFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageNoFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), None) )

    let msg_id = MsgId(1)
    let frac_ids = None

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestSameMessageDifferentFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageDifferentFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [1] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 2] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageDifferentFracs2 is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageDifferentFracs2"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [1] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 1; 2] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageDifferentFracs3 is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageDifferentFracs3"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), None ) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 1; 2] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageDifferentFracs4 is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageDifferentFracs4"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [1] end) )

    let msg_id = MsgId(1)
    let frac_ids = None

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageSameFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageSameFrac"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestMatchIsLater is UnitTest
  fun name(): String =>
    "message_deduplicator/MatchIsLater"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [1] end) )
    list.push( (MsgId(1), recover [10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestMatchIsLater2 is UnitTest
  fun name(): String =>
    "message_deduplicator/MatchIsLater2"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover [1; 5] end) )
    list.push( (MsgId(1), recover [10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestMatchIsLater3 is UnitTest
  fun name(): String =>
    "message_deduplicator/MatchIsLater3"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(2), recover [1; 5] end) )
    list.push( (MsgId(1), recover [10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)
