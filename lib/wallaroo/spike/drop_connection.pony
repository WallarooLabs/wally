use "random"
use "wallaroo/network"

class DropConnection is WallarooOutgoingNetworkActorNotify
  let _letter: WallarooOutgoingNetworkActorNotify
  let _dice: Dice
  let _prob: U64

  new iso create(seed: U64, prob: U64,
    letter: WallarooOutgoingNetworkActorNotify iso)
  =>
    _dice = Dice(MT(seed))
    _prob = prob
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
    _dice(1, 100) <= _prob

  fun ref drop(conn: WallarooOutgoingNetworkActor ref) =>
    ifdef debug then
      @printf[I32]("<<<<<<SPIKE: DROPPING CONNECTION!>>>>>>\n".cstring())
    end
    conn.close()
