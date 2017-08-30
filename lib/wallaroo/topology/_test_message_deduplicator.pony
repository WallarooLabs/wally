use "sendence/connemara"
use "wallaroo/core"

actor _TestMessageDeduplicator is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestEmptyDuplicates)
    test(_TestDifferentMessagesNoFracs)
    test(_TestDifferentMessagesSameFracs)
    test(_TestSameMessageNoFracs)
    test(_TestSameMessageDifferentFracs)
    test(_TestSameMessageDifferentFracs2)
    test(_TestSameMessageSameFracs)
    test(_TestMatchIsLater)
    test(_TestMatchIsLater2)
    test(_TestMatchIsLater3)

class _TestEmptyDuplicates is UnitTest
  fun name(): String =>
    "message_deduplicator/EmptyDuplicates"

  fun ref apply(h: TestHelper) =>
    let empty = DeduplicationList.create()
    let is_dup = _MessageDeduplicator.is_duplicate(1, None, empty)

    h.assert_eq[Bool](false, is_dup)

class _TestDifferentMessagesNoFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/DifferentMessagesNoFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), None) )

    let msg_id = MsgId(2)
    let frac_ids = None

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestDifferentMessagesSameFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/DifferentMessagesSameFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover val [as U32: 1] end) )

    let msg_id = MsgId(2)
    let frac_ids = recover val [as U32: 1] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageNoFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageNoFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), None) )

    let msg_id = MsgId(1)
    let frac_ids = None

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestSameMessageDifferentFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageDifferentFracs"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover val [as U32: 1] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 2] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageDifferentFracs2 is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageDifferentFracs2"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover val [as U32: 1] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 1, 2] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](false, is_dup)

class _TestSameMessageSameFracs is UnitTest
  fun name(): String =>
    "message_deduplicator/SameMessageSameFrac"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover val [as U32: 10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestMatchIsLater is UnitTest
  fun name(): String =>
    "message_deduplicator/MatchIsLater"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover val [as U32: 1] end) )
    list.push( (MsgId(1), recover val [as U32: 10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestMatchIsLater2 is UnitTest
  fun name(): String =>
    "message_deduplicator/MatchIsLater2"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(1), recover val [as U32: 1, 5] end) )
    list.push( (MsgId(1), recover val [as U32: 10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)

class _TestMatchIsLater3 is UnitTest
  fun name(): String =>
    "message_deduplicator/MatchIsLater3"

  fun ref apply(h: TestHelper) =>
    let list = DeduplicationList.create()
    list.push( (MsgId(2), recover val [as U32: 1, 5] end) )
    list.push( (MsgId(1), recover val [as U32: 10] end) )

    let msg_id = MsgId(1)
    let frac_ids = recover val [as U32: 10] end

    let is_dup = _MessageDeduplicator.is_duplicate(msg_id, frac_ids, list)

    h.assert_eq[Bool](true, is_dup)
