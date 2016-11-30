use "ponytest"
use "buffered"
use "collections"
use "promises"
use "wallaroo/messages"
use "wallaroo/resilience"
use "wallaroo/topology"

actor Main is TestList

  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestOriginSet)
    test(_TestHashOriginRoute)
    test(_TestHighWatermarkTable)
    test(_TestBookkeeping)
    test(_TestUpdateWatermark)
    test(_TestEventLog)


actor _TestOrigin is Origin
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _origins: OriginSet = OriginSet(10)

  fun ref hwm_get(): HighWatermarkTable => _hwm
  fun ref lwm_get(): LowWatermarkTable => _lwm
  fun ref seq_translate_get(): SeqTranslationTable => _seq_translate
  fun ref route_translate_get(): RouteTranslationTable => _route_translate
  fun ref origins_get(): OriginSet => _origins
  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    None

class iso _TestOriginSet is UnitTest
  fun name(): String =>
    "messages/OriginSet"

  fun apply(h: TestHelper) =>
    let set = OriginSet(1)
    let o1: Origin tag = _TestOrigin
    set.set(o1)
    h.assert_true(set.contains(o1))

class iso _TestHashOriginRoute is UnitTest
  fun name(): String =>
    "messages/HashOriginRoute"

  fun apply(h: TestHelper) =>
    let origin: Origin tag = _TestOrigin
    let route: U64 = U64(1)
    let pair: OriginRoutePair = (origin, route)
    let hash1: U64 = HashOriginRoute.hash(pair)
    let hash2: U64 = HashOriginRoute.hash(pair)
    h.assert_true(hash1 == hash2)
    h.complete(HashOriginRoute.eq(pair, pair))


class iso _TestHighWatermarkTable is UnitTest
  fun name(): String =>
    "messages/HighWatermarkTable"

  fun apply(h: TestHelper) =>
    let hwm: HighWatermarkTable = HighWatermarkTable(10)
    let origin: Origin tag = _TestOrigin
    let route: U64 = U64(1)
    let pair: OriginRoutePair = (origin, route)
    let seq_id: U64 = U64(100)
    hwm.update(pair, seq_id)

    try
      let result = hwm(pair)
      h.assert_true(result == seq_id)
    else
      h.fail("HighWatermarkTable lookup failed!")
    end

class iso _TestBookkeeping is UnitTest
  fun name(): String =>
    "messages/bookkeeping"

  fun apply(h: TestHelper) =>
    None

class iso _TestUpdateWatermark is UnitTest
  fun name(): String =>
    "messages/UpdateWatermark"

  fun apply(h: TestHelper) =>
    None


    // h.complete(false)
    // h.fail("test failed")
    // h.long_test(5_000_000_000)

actor TestOrigin is ResilientOrigin
  let _replayed: Array[U64] ref = _replayed.create()
  let h: TestHelper
  let message_count: U64
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _origins: OriginSet = OriginSet(10)
  let sc: TestStateChange = TestStateChange(42)
  let state: TestState = TestState
  var _next_to_be_replayed: U128 = 0
  let _reader: Reader = Reader
  let _writer: Writer = Writer
  var _target_sum: U64 = 0
  let alfred: Alfred
  let buffer: StandardEventLogBuffer
  let _finished: Promise[None]

  new create(h': TestHelper, message_count': U64, finished: Promise[None]) =>
    h = h'
    message_count = message_count'
    alfred = Alfred(h.env,"/tmp/test_event_log.evlog")
    buffer = StandardEventLogBuffer(alfred,0)
    alfred.register_origin(this,0)
    alfred.start()
    _finished = finished

  be replay_log_entry(uid: U128, frac_ids: (Array[U64] val | None),
    statechange_id: U64, payload: ByteSeq val) =>
    h.assert_true(uid == _next_to_be_replayed)
    _next_to_be_replayed = _next_to_be_replayed + 1
    try
      _reader.append(payload as Array[U8] val)
    else
      @printf[I32]("the world is broken\n".cstring())
    end
    sc.read_log_entry(_reader)
    sc.apply(state)

  be replay_finished() =>
    h.assert_true(state.sum == _target_sum)

  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    None

  be start_without_replay() =>
    let ts = TestState
    for i in Range(0, message_count.usize()) do
      _target_sum = _target_sum + i.u64()
      sc.value = i.u64()
      sc.write_log_entry(_writer)
      alfred.queue_log_entry(0, i.u128(), None, sc.id(), i.u64(), _writer.done())
    end
    alfred.flush_buffer(0, message_count, this, 0, 0)

  be log_flushed(low_watermark: U64, messages_flushed: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64)
  =>
    h.assert_true(low_watermark == message_count)
    h.assert_true(messages_flushed == message_count)
    let alfred2 = Alfred(h.env,"/tmp/test_event_log.evlog")
    let buffer2 = StandardEventLogBuffer(alfred2,0)
    alfred2.register_origin(this,0)
    alfred2.start()

  fun ref hwm_get(): HighWatermarkTable => _hwm
  fun ref lwm_get(): LowWatermarkTable => _lwm
  fun ref seq_translate_get(): SeqTranslationTable => _seq_translate
  fun ref route_translate_get(): RouteTranslationTable => _route_translate
  fun ref origins_get(): OriginSet => _origins

class TestState
  var sum: U64 = 0

class TestStateChange is StateChange[TestState]
  var _id: U64
  var value: U64 = 0

  new create(id': U64) => _id = id'
  fun name(): String val => "TestStateChange"
  fun id(): U64 => _id
  fun apply(state: TestState) => state.sum = state.sum + value

  fun write_log_entry(out_writer: Writer) =>
    out_writer.u64_be(value)

  fun ref read_log_entry(in_reader: Reader) =>
    try
      value = in_reader.u64_be()
    else
      @printf[I32]("the world is broken\n".cstring())
    end

class iso _TestEventLog is UnitTest

  fun name(): String => "resilience/alfred"

  fun ref apply(h: TestHelper) =>
    let msg_count: U64 = 100
    let finished: Promise[None] = finished.create()
    let origin = TestOrigin(h, msg_count, finished)
//    finished.next[None](recover iso lambda() => None end end)
