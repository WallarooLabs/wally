use "ponytest"
use "wallaroo/messages"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestOriginSet)
    test(_TestHashOriginRoute)
    test(_TestHighWatermarkTable)
    test(_TestTranslationTable)
    test(_TestBookkeeping)
    test(_TestUpdateWatermark)


class _TestOrigin is Origin 
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _translate: TranslationTable = TranslationTable(10)
  let _origins: OriginSet = OriginSet(10)

  fun ref _hwm_get(): HighWatermarkTable =>
    _hwm
  
  fun ref _lwm_get(): LowWatermarkTable =>
    _lwm
    
  fun ref _translate_get(): TranslationTable =>
    _translate
  
  fun ref _origins_get(): OriginSet =>
    _origins

  fun ref bookkeeping(incoming_envelope: MsgEnvelope box,
    outgoing_envelope: MsgEnvelope box) =>
    _bookkeeping(incoming_envelope, outgoing_envelope)

    
class iso _TestOriginSet is UnitTest
  fun name(): String =>
    "messages/OriginSet"

  fun apply(h: TestHelper) =>
    let set = OriginSet(1)
    let o1: Origin = _TestOrigin
    set.set(o1)
    h.assert_true(set.contains(o1))

class iso _TestHashOriginRoute is UnitTest
  fun name(): String =>
    "messages/HashOriginRoute"

  fun apply(h: TestHelper) =>
    let origin: Origin = _TestOrigin
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
    let origin: Origin = _TestOrigin
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

    
class iso _TestTranslationTable is UnitTest
  fun name(): String =>
    "messages/TranslationTable"

  fun apply(h: TestHelper) =>
    let translate: TranslationTable = TranslationTable(10)    
    let origin: Origin = _TestOrigin
    let incoming_seq_id: U64 = U64(1)
    let outgoing_seq_id: U64 = U64(2)

    translate.update(incoming_seq_id, outgoing_seq_id)
    try
      let outToIn = translate.outToIn(outgoing_seq_id)
      h.assert_true(outToIn == incoming_seq_id)
    else
      h.fail("TranslationTable lookup failed!")
    end
    try
      let inToOut = translate.inToOut(incoming_seq_id)
      h.assert_true(inToOut == outgoing_seq_id)
    else
      h.fail("TranslationTable lookup failed!")
    end

    
class iso _TestBookkeeping is UnitTest
  fun name(): String =>
    "messages/Bookkeeping"

  fun apply(h: TestHelper) =>
    let origin_A: _TestOrigin = _TestOrigin
    let origin_B: _TestOrigin = _TestOrigin
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
    origin_B.bookkeeping(incoming_envelope, outgoing_envelope)
    
    // check HighWatermarkTable
    try
      let high_watermark = origin_B._hwm_get().apply((origin_A, route_id_B))
      h.assert_true(outgoing_seq_id == high_watermark)
    else
      h.fail("Lookup in HighWatermarkTable failed!")
    end
    // check TranslationTable
    try
      let outToIn = origin_B._translate_get().outToIn(outgoing_seq_id)
      h.assert_true(incoming_seq_id == outToIn)
    else
      h.fail("TranslationTable.outToIn failed!")
    end
    try
      let inToOut = origin_B._translate_get().inToOut(incoming_seq_id)
      h.assert_true(outgoing_seq_id == inToOut)
    else
      h.fail("TranslationTable.inToOut failed!")
    end

class iso _TestUpdateWatermark is UnitTest
  fun name(): String =>
    "messages/UpdateWatermark"

  fun apply(h: TestHelper) =>
    let origin_A: _TestOrigin = _TestOrigin
    let origin_B: _TestOrigin = _TestOrigin
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
    origin_B.bookkeeping(incoming_envelope, outgoing_envelope)
    // update watermark
    let downstream_route_id: U64 = U64(11)
    let downstream_seq_id: U64 = U64(2)
    origin_B._update_watermark(downstream_route_id, downstream_seq_id)

    // check low watermark
    let low_watermark = origin_B._lwm_get().low_watermark()
    h.assert_true(downstream_seq_id == low_watermark)




