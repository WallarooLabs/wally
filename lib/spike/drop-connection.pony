use "net"
use "random"

class DropConnection is TCPConnectionNotify
  let _letter: TCPConnectionNotify
  let _dice: Dice
  let _prob: U64

  new iso create(seed: U64, prob: U64, letter: TCPConnectionNotify iso) =>
    _dice = Dice(MT(seed))
    _prob = prob
    _letter = consume letter

  fun ref accepted(conn: TCPConnection ref) =>
    if spike() then
      drop(conn)
    end

    _letter.accepted(conn)

  fun ref connecting(conn: TCPConnection ref, count: U32) =>
    if spike() then
      drop(conn)
    end

    _letter.connecting(conn, count)

  fun ref connected(conn: TCPConnection ref) =>
    if spike() then
      drop(conn)
    end

    _letter.connected(conn)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _letter.connect_failed(conn)

  fun ref auth_failed(conn: TCPConnection ref) =>
    _letter.auth_failed(conn)

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq ? =>
    if spike() then
      drop(conn)
      ""
    else
      _letter.sent(conn, data)
    end

  fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter ? =>
    if spike() then
      drop(conn)
      recover Array[String] end
    else
      _letter.sentv(conn, data)
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    if spike() then
      drop(conn)
    end
    // We need to always send the data we've read from the buffer along.
    // Even when we drop the connection, we've already read that data
    // and _letter is still expecting it.
    _letter.received(conn, consume data)

  fun ref expect(conn: TCPConnection ref, qty: USize): USize =>
    _letter.expect(conn, qty)

  fun ref closed(conn: TCPConnection ref) =>
    _letter.closed(conn)

  fun ref spike(): Bool =>
    _dice(1, 100) < _prob

  fun ref drop(conn: TCPConnection ref) =>
    conn.close()
