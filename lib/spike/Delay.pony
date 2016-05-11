use "collections"
use "net"
use "random"

class Delay is TCPConnectionNotify
  let _letter: TCPConnectionNotify
  let _rdelayer: _ReceivedDelayer

  new create(seed: U64,
    delayer_config: DelayerConfig,
    letter: TCPConnectionNotify iso)
  =>
    _letter = consume letter
    _rdelayer = _ReceivedDelayer(delayer_config)

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
    _rdelayer.received(conn, consume data, this)

  fun ref expect(conn: TCPConnection ref, qty: USize): USize =>
    _rdelayer.expect = _letter.expect(conn, qty)
    0

  fun ref closed(conn: TCPConnection ref) =>
    _letter.closed(conn)

  fun ref _letter_received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _letter.received(conn, consume data)

class DelayerConfig
  let seed: U64
  let through_min_bytes: U64
  let through_max_bytes: U64
  let delay_min_bytes: U64
  let delay_max_bytes: U64

  new create(seed': U64,
    through_min_bytes': U64,
    through_max_bytes': U64,
    delay_min_bytes': U64,
    delay_max_bytes': U64)
  =>
    seed = seed'
    through_min_bytes = through_min_bytes'
    through_max_bytes = through_max_bytes'
    delay_min_bytes = delay_min_bytes'
    delay_max_bytes = delay_max_bytes'

class _ReceivedDelayer
  var _delaying: Bool = false
  embed _delayed: Buffer = Buffer
  let _config: DelayerConfig
  let _dice: Dice
  var _next_received_spike_flip: U64 = 0
  var expect: USize = 0

  new create(config: DelayerConfig) =>
    _config = config
    _dice = Dice(MT(config.seed))

  fun ref received(conn: TCPConnection ref,
    data: Array[U8] iso,
    notifier: Delay)
  =>
    _delayed.append(consume data)

    while _should_deliver_received() do
      if expect <= _delayed.size() then
        try _deliver_received(conn, notifier) end
      else
        break
      end
    end

  fun ref _should_deliver_received(): Bool =>
    """
    When delaying received, flip once our buffer size is greater than or
    equal to our next flip size

    When not delaying received, flip once our next flip value drops to or
    below 0
    """
    if _delaying then
      if _delayed.size().u64() >= _next_received_spike_flip then
        _delaying = false
        _next_received_spike_flip =
          _dice(_config.through_min_bytes,
          _config.through_max_bytes)
      end
    else
      if _next_received_spike_flip <= 0 then
        _delaying = true
        _next_received_spike_flip =
          _dice(_config.delay_min_bytes,
            _config.delay_max_bytes)
      end
    end

    _delaying == false

  fun ref _deliver_received(conn: TCPConnection ref, notifier: Delay) ? =>
    let data' = _delayed.block(expect)
    _next_received_spike_flip = _next_received_spike_flip - expect.u64()
    notifier._letter_received(conn, consume data')
