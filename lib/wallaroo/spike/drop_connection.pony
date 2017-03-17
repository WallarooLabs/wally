use "random"
use "wallaroo/network"

class DropConnection is WallarooOutgoingNetworkActorNotify
  let _letter: WallarooOutgoingNetworkActorNotify
  let _rand: Random
  let _prob: F64
  let _margin: USize
  var _count_since_last_dropped: USize

  new iso create(config: SpikeConfig,
    letter: WallarooOutgoingNetworkActorNotify iso)
  =>
    _rand = MT(config.seed)
    _prob = config.prob
    _margin = config.margin
    // allow first hit of spike returning true on probability to drop
    _count_since_last_dropped = config.margin
    _letter = consume letter

  fun ref connecting(conn: WallarooOutgoingNetworkActor ref, count: U32) =>
    if spike() then
      drop(conn)
    end

    _letter.connecting(conn, count)

  fun ref connected(conn: WallarooOutgoingNetworkActor ref) =>
    if spike() then
      drop(conn)
    end

    _letter.connected(conn)

  fun ref connect_failed(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.connect_failed(conn)

  fun ref closed(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.closed(conn)

  fun ref sentv(conn: WallarooOutgoingNetworkActor ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    if spike() then
      drop(conn)
    end

    _letter.sentv(conn, data)

  fun ref received(conn: WallarooOutgoingNetworkActor ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if spike() then
      drop(conn)
    end
    // We need to always send the data we've read from the buffer along.
    // Even when we drop the connection, we've already read that data
    // and _letter is still expecting it.
    _letter.received(conn, consume data, n)
    true

  fun ref expect(conn: WallarooOutgoingNetworkActor ref, qty: USize): USize =>
    _letter.expect(conn, qty)

   fun ref throttled(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.throttled(conn)

  fun ref unthrottled(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.unthrottled(conn)

  fun ref spike(): Bool =>
    if _rand.real() <= _prob then
      if _margin == 0 then
        true
      elseif _count_since_last_dropped >= _margin then
        // reset count, return true
        _count_since_last_dropped = 0
        true
      else
        _count_since_last_dropped = _count_since_last_dropped + 1
        false
      end
    else
      false
    end

  fun ref drop(conn: WallarooOutgoingNetworkActor ref) =>
    ifdef debug then
      @printf[I32]("<<<<<<SPIKE: DROPPING CONNECTION!>>>>>>\n".cstring())
    end
    conn.close()
