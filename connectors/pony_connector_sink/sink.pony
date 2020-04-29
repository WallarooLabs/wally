use "buffered"
use "collections"
use "debug"
use "net"

use cwm = "wallaroo_labs/connector_wire_messages"

primitive MessageMessageToArray
  fun apply(mm: (cwm.MessageBytes | ByteSeqIter | None)): Array[U8] val =>
    recover
      match mm
      | None =>
        []
      | let mm': String =>
        Array[U8] .> concat(mm'.values())
      | let mm': Array[U8] val =>
        Array[U8] .> concat(mm'.values())
      | let mm': ByteSeqIter =>
        let data' = Array[U8]
        for v in mm'.values() do
          match v
          | let s: String =>
            data'.concat(s.values())
          | let a: Array[U8] val =>
            data'.concat(a.values())
          end
        end
        data'
      end
    end

class SinkTCPConnectionNotify is TCPConnectionNotify
  let _out: OutStream
  let _active_workers: ActiveWorkers
  var _sm: SinkStateMachine
  var _awaiting_size: Bool

  new iso create(out: OutStream, active_workers: ActiveWorkers) =>
    _out = out
    _active_workers = active_workers
    _sm = UnconnectedSinkStateMachine
    _awaiting_size = true
    Debug("waiting for messages now")

  fun ref accepted(conn: TCPConnection ref) =>
    Debug("Connecting notifier connected")

    _sm = ConnectedSinkStateMachine(conn, _active_workers, InitialState)

    try
      conn.expect(4)?
    else
      Debug("error setting expect to size size")
    end

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    Debug("received")
    if _awaiting_size then
      let rb = Reader .> append(consume data)
      let size = try
        rb.u32_be()?
      else
        conn.close()
        Debug("error reading size, closing connection")
        return true
      end

      Debug("size is " + size.string())

      try
        conn.expect(size.usize())?
      else
        Debug("error setting expect to message size")
      end

      _awaiting_size = false
    else
      Debug("received some data")
      let msg = try
        recover iso
          cwm.Frame.decode(consume data)?
        end
      else
        conn.close()
        Debug("error decoding frame, closing connection")
        return true
      end

      _sm(consume msg)

      try
        conn.expect(4)?
      else
        Debug("error setting expect to message size")
      end

      _awaiting_size = true
    end

    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

class SinkTCPListenNotify is TCPListenNotify
  let _out: OutStream
  let _active_workers: ActiveWorkers

  new iso create(out: OutStream, active_workers: ActiveWorkers) =>
    _out = out
    _active_workers = active_workers

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    Debug("connected")
    SinkTCPConnectionNotify(_out, _active_workers)

  fun ref not_listening(listen: TCPListener ref) =>
    None

actor Main
  new create(env: Env) =>
    let active_workers = ActiveWorkers

    try
      TCPListener(env.root as AmbientAuth,
        SinkTCPListenNotify(env.out, active_workers), "", "8989")
    end
