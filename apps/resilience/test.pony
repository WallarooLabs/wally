use "ponytest"
use "wallaroo/messages"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestOriginSet)
    test(_TestHashOriginRoute)
    test(_TestHighWatermarkTable)
    test(_TestSeqTranslationTable)
    test(_TestBookkeeping)
    test(_TestUpdateWatermark)


actor _TestOrigin is Origin 
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _origins: OriginSet = OriginSet(10)
  let h: TestHelper
  var _high_watermark: U64 = U64(0)

  new create(h': TestHelper) =>
    h = h'
  
  fun ref hwm_get(): HighWatermarkTable =>
    _hwm

  fun ref lwm_get(): LowWatermarkTable =>
    _lwm
    
  fun ref seq_translate_get(): SeqTranslationTable =>
    _seq_translate

  fun ref route_translate_get(): RouteTranslationTable =>
    _route_translate
  
  fun ref origins_get(): OriginSet =>
    _origins

  fun ref _flush(low_watermark: U64, origin: Origin tag,
    upstream_route_id: U64 , upstream_seq_id: U64) =>
    None
    
  be bookkeeping(incoming_envelope: MsgEnvelope val,
    outgoing_envelope: MsgEnvelope val) =>
    _bookkeeping(incoming_envelope, outgoing_envelope)
    try
      match incoming_envelope.origin
      | let origin: Origin tag =>
        _high_watermark = hwm_get().apply((origin, outgoing_envelope.route_id))
      end
    else
      h.fail("high_watermark lookup failed!")
    end

  be check_high_watermark(high_watermark': U64) =>
    h.assert_true(_high_watermark == high_watermark')
    h.complete(true)

  be check_low_watermark(low_watermark': U64) =>
    let low_watermark = lwm_get().low_watermark()
    h.log("low_watermark: " + low_watermark.string())
    h.assert_true(low_watermark == low_watermark')
    h.complete(true)
    
class iso _TestOriginSet is UnitTest
  fun name(): String =>
    "messages/OriginSet"

  fun apply(h: TestHelper) =>
    let set = OriginSet(1)
    let o1: Origin tag = _TestOrigin(h)
    set.set(o1)
    h.assert_true(set.contains(o1))

class iso _TestHashOriginRoute is UnitTest
  fun name(): String =>
    "messages/HashOriginRoute"

  fun apply(h: TestHelper) =>
    let origin: Origin tag = _TestOrigin(h)
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
    let origin: Origin tag = _TestOrigin(h)
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

    
class iso _TestSeqTranslationTable is UnitTest
  fun name(): String =>
    "messages/TranslationTable"

  fun apply(h: TestHelper) =>
    let seq_translate: SeqTranslationTable = SeqTranslationTable(10)    
    let origin: Origin tag = _TestOrigin(h)
    let incoming_seq_id: U64 = U64(1)
    let outgoing_seq_id: U64 = U64(2)

    seq_translate.update(incoming_seq_id, outgoing_seq_id)
    try
      let outToIn = seq_translate.outToIn(outgoing_seq_id)
      h.assert_true(outToIn == incoming_seq_id)
    else
      h.fail("TranslationTable lookup failed!")
    end
    try
      let inToOut = seq_translate.inToOut(incoming_seq_id)
      h.assert_true(inToOut == outgoing_seq_id)
    else
      h.fail("TranslationTable lookup failed!")
    end

    
class iso _TestBookkeeping is UnitTest
  var _high_watermark: U64 = U64(0)
  
  fun name(): String =>
    "messages/Bookkeeping"

  fun ref hwm_callback(watermark: U64) =>
    _high_watermark = watermark
    
  fun apply(h: TestHelper) =>
    let origin_A: _TestOrigin tag = _TestOrigin(h)
    let origin_B: _TestOrigin tag = _TestOrigin(h)
    let msg_uid: U128 = U128(1234567890)
    let frac_ids_A: (Array[U64] val | None) = None
    let frac_ids_B: (Array[U64] val | None) = None
    let incoming_seq_id: U64 = 1
    let outgoing_seq_id: U64 = 2
    let route_id_A: U64 = 1
    let route_id_B: U64 = 11
    let incoming_envelope = MsgEnvelope(origin_A, msg_uid, frac_ids_A,
      incoming_seq_id, route_id_A)
    let outgoing_envelope = MsgEnvelope(origin_B, msg_uid, frac_ids_B,
      outgoing_seq_id, route_id_B)

    // do some bookkeeping
    origin_B.bookkeeping(incoming_envelope.clone(), outgoing_envelope.clone())
    
    // check high watermark
    origin_B.check_high_watermark(outgoing_envelope.seq_id)
    h.long_test(1_000_000_000)


class iso _TestUpdateWatermark is UnitTest
  fun name(): String =>
    "messages/UpdateWatermark"

  fun apply(h: TestHelper) =>
    let origin_A: _TestOrigin tag = _TestOrigin(h)
    let origin_B: _TestOrigin tag = _TestOrigin(h)
    let msg_uid: U128 = U128(1234567890)
    let frac_ids_A: (Array[U64] val | None) = None
    let frac_ids_B: (Array[U64] val | None) = None
    let incoming_seq_id: U64 = 1
    let outgoing_seq_id: U64 = 2
    let route_id_A: U64 = 1
    let route_id_B: U64 = 11
    let incoming_envelope = MsgEnvelope(origin_A, msg_uid, frac_ids_A,
      incoming_seq_id, route_id_A)
    let outgoing_envelope = MsgEnvelope(origin_B, msg_uid, frac_ids_B,
      outgoing_seq_id, route_id_B)

    // do some bookkeeping
    origin_B.bookkeeping(incoming_envelope.clone(), outgoing_envelope.clone())
    // update watermark
    let downstream_route_id: U64 = U64(11)
    let downstream_seq_id: U64 = U64(2)
    origin_B.update_watermark(downstream_route_id, downstream_seq_id)

    // check low watermark
    origin_B.check_low_watermark(downstream_seq_id)
    h.long_test(1_000_000_000)





