use "collections"
use "net"
use "random"
use "time"

class DelayReceived is TCPConnectionNotify
  let _letter: TCPConnectionNotify
  let _delayer: _ReceivedDelayer

  new create(letter: TCPConnectionNotify iso,
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

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq ? =>
    _letter.sent(conn, data)

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter ? =>
    _letter.sentv(conn, data)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _delayer.received(conn, consume data, this)

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

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq ? =>
    _delayer.sent(conn, data, this)

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter ? =>
    _delayer.sentv(conn, data, this)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _letter.received(conn, consume data)

  fun ref expect(conn: TCPConnection ref, qty: USize): USize =>
    _letter.expect(conn, qty)

  fun ref closed(conn: TCPConnection ref) =>
    _letter.closed(conn)

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
    delay_max_bytes': USize = 100)
  =>
    seed = seed'
    through_min_bytes = through_min_bytes'
    through_max_bytes = through_max_bytes'
    delay_min_bytes = delay_min_bytes'
    delay_max_bytes = delay_max_bytes'

class _SentDelayer
  let _config: DelayerConfig
  let _dice: Dice
  embed _delayed: Buffer = Buffer
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
    if _delaying then
      if _delayed.size() >= _next_delaying_flip then
        _delaying = false
        _next_delaying_flip = _dice(
          _config.through_min_bytes.u64(),
          _config.through_max_bytes.u64()).usize()
      end
    else
      if _next_delaying_flip <= 0 then
        _delaying = true
        _next_delaying_flip = _dice(
          _config.delay_min_bytes.u64(),
          _config.delay_max_bytes.u64()).usize()
      end
    end

    _delaying == false

class _ReceivedDelayer
  var _delaying: Bool = false
  embed _delayed: Buffer = Buffer
  let _config: DelayerConfig
  let _dice: Dice
  var _next_received_spike_flip: USize = 0
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
    """
    When delaying received, roll once our buffer size is greater than or
    equal to our next roll size

    When not delaying received, roll once our next roll value drops to or
    below 0
    """
    if _delaying then
      if _delayed.size() >= _next_received_spike_flip then
        _delaying = false
        _next_received_spike_flip =
          _dice(_config.through_min_bytes.u64(),
          _config.through_max_bytes.u64()).usize()
      end
    else
      if _next_received_spike_flip == 0 then
        _delaying = true
        _next_received_spike_flip =
          _dice(_config.delay_min_bytes.u64(),
            _config.delay_max_bytes.u64()).usize()
      end
    end

    _delaying == false

  fun ref _deliver_received(conn: TCPConnection ref,
    notifier: DelayReceived) ?
  =>
    let data' = _delayed.block(expect)
    _next_received_spike_flip = _next_received_spike_flip - expect
    notifier._letter_received(conn, consume data')
