use "collections"
use "net"
use "buffered"
use "random"
use "time"

/*
class DelayerConfig
  let seed: U64
  let through_min_bytes: USize
  let through_max_bytes: USize
  let delay_min_bytes: USize
  let delay_max_bytes: USize

  new iso create(seed': U64 = Time.millis(),
    through_min_bytes': USize = 1,
    through_max_bytes': USize = 1000,
    delay_min_bytes': USize = 1,
    delay_max_bytes': USize = 500)
  =>
    seed = seed'
    through_min_bytes = through_min_bytes'
    through_max_bytes = through_max_bytes'
    delay_min_bytes = delay_min_bytes'
    delay_max_bytes = delay_max_bytes'

class DelayReceived is TCPConnectionNotify
  let _letter: TCPConnectionNotify
  let _delayer: _ReceivedDelayer

  new iso create(letter: TCPConnectionNotify iso,
    delayer_config: DelayerConfig iso = DelayerConfig)
  =>
    _letter = consume letter
    _delayer = _ReceivedDelayer(consume delayer_config)

  fun ref accepted(conn: TCPConnection ref) =>
    _letter.accepted(conn)

  fun ref connecting(conn: TCPConnection ref, count: U32) =>
    _letter.connecting(conn, count)

  fun ref connected(conn: TCPConnection ref) =>
    _letter.connected(conn)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _letter.connect_failed(conn)

  fun ref auth_failed(conn: TCPConnection ref) =>
    _letter.auth_failed(conn)

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq =>
    _letter.sent(conn, data)

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter =>
    _letter.sentv(conn, data)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    _delayer.received(conn, consume data, this, n)
    true

  fun ref expect(conn: TCPConnection ref, qty: USize): USize =>
    _delayer.expect = _letter.expect(conn, qty)
    0

  fun ref closed(conn: TCPConnection ref) =>
    _letter.closed(conn)

  fun ref _letter_received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _letter.received(conn, consume data)

class DelaySent is TCPConnectionNotify
  let _letter: TCPConnectionNotify
  let _delayer: _SentDelayer

  new create(letter: TCPConnectionNotify iso,
    delayer_config: DelayerConfig iso = DelayerConfig)
  =>
    _letter = consume letter
    _delayer = _SentDelayer(consume delayer_config)

  fun ref accepted(conn: TCPConnection ref) =>
    _letter.accepted(conn)

  fun ref connecting(conn: TCPConnection ref, count: U32) =>
    _letter.connecting(conn, count)

  fun ref connected(conn: TCPConnection ref) =>
    _letter.connected(conn)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _letter.connect_failed(conn)

  fun ref auth_failed(conn: TCPConnection ref) =>
    _letter.auth_failed(conn)

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq =>
    try
      _delayer.sent(conn, data, this)
    else
      ""
    end

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter =>
    try
      _delayer.sentv(conn, data, this)
    else
      recover Array[String] end
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    _letter.received(conn, consume data, n)
    true

  fun ref expect(conn: TCPConnection ref, qty: USize): USize =>
    _letter.expect(conn, qty)

  fun ref closed(conn: TCPConnection ref) =>
    _letter.closed(conn)

class _ReceivedDelayer is _Delayer
  var _delaying: Bool = false
  embed _delayed: Reader = Reader
  let _config: DelayerConfig
  let _dice: Dice
  var _next_delaying_flip: USize = 0
  var expect: USize = 0

  new create(config: DelayerConfig) =>
    _config = config
    _dice = Dice(MT(config.seed))

  fun ref received(conn: TCPConnection ref,
    data: Array[U8] iso,
    notifier: DelayReceived)
  =>
    _delayed.append(consume data)

    if _should_deliver_received() then
      while (_delayed.size() > 0) and (expect <= _delayed.size()) do
        try _deliver_received(conn, notifier) end
      end
    end

  fun ref _should_deliver_received(): Bool =>
    _check_for_flip()

    _delaying == false

  fun ref _check_for_flip() =>
    """
    When delaying received, flip once our buffer size is greater than or
    equal to our next flip size

    When not delaying received, flip once our next flip value drops to or
    below 0
    """
    if _delaying then
      if _delayed.size() >= _next_delaying_flip then
        _start_allowing()
      end
    else
      if _next_delaying_flip <= 0 then
        _start_delaying()
      end
    end

  fun ref _start_allowing() =>
    _delaying = false
    _next_delaying_flip = _bytes_to_allow(_config, _delayed, _dice)

  fun ref _start_delaying() =>
    _delaying = true
    _next_delaying_flip = _bytes_to_delay(_config, _dice)

  fun ref _deliver_received(conn: TCPConnection ref,
    notifier: DelayReceived) ?
  =>
    let s = if expect == 0 then _delayed.size() else expect end
    let data' = _delayed.block(s)
    _next_delaying_flip = _next_delaying_flip - s
    notifier._letter_received(conn, consume data')


class _SentDelayer is _Delayer
  let _config: DelayerConfig
  let _dice: Dice
  embed _delayed: Reader = Reader
  var _delaying: Bool = false
  var _next_delaying_flip: USize = 0

  new create(config: DelayerConfig) =>
    _config = config
    _dice = Dice(MT(config.seed))

  fun ref sent(conn: TCPConnection ref,
    data: ByteSeq,
    notifier: DelaySent)
    : ByteSeq ?
  =>
    let data' = notifier.sent(conn, data)
    match data'
      | let d: Array[U8] val => _delayed.append(d)
      | let d: String => _delayed.append(d.array())
    else
      error
    end

    if _should_deliver_sent() then
      _next_delaying_flip = _next_delaying_flip - _delayed.size()
      _delayed.block(_delayed.size())
    else
      ""
    end

  fun ref sentv(conn: TCPConnection ref,
    data: ByteSeqIter,
    notifier: DelaySent)
    : ByteSeqIter ?
  =>
    let data' = notifier.sentv(conn, data)
    for bytes in data'.values() do
      match bytes
        | let b: Array[U8] val => _delayed.append(b)
        | let b: String => _delayed.append(b.array())
      else
        error
      end
    end

    if _should_deliver_sent() then
      _next_delaying_flip = _next_delaying_flip - _delayed.size()
      let s = _delayed.block(_delayed.size())
      recover Array[Array[U8]].push(consume s) end
    else
      recover Array[String] end
    end

  fun ref _should_deliver_sent(): Bool =>
    _check_for_flip()
    _delaying == false

  fun ref _check_for_flip() =>
    if _delaying then
      if _delayed.size() >= _next_delaying_flip then
        _start_allowing()
      end
    else
      if _next_delaying_flip <= 0 then
        _start_delaying()
      end
    end

  fun ref _start_allowing() =>
    _delaying = false
    _next_delaying_flip = _bytes_to_allow(_config, _delayed, _dice)

  fun ref _start_delaying() =>
    _delaying = true
    _next_delaying_flip = _bytes_to_delay(_config, _dice)

trait _Delayer
  fun ref _bytes_to_allow(c: DelayerConfig, b: Reader, d: Dice): USize =>
    let i = _next_interval(c.through_min_bytes, c.through_max_bytes, d)
    i + b.size()

  fun ref _bytes_to_delay(c: DelayerConfig, d: Dice): USize =>
    _next_interval(c.delay_min_bytes, c.delay_max_bytes, d)

  fun ref _next_interval(min: USize, max: USize, d: Dice): USize =>
    d(min.u64(), max.u64()).usize()
*/
