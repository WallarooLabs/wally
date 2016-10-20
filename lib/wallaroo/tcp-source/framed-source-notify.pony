interface FramedSourceHandler
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] iso): Array[U8] val ?

class FramedSourceNotify is TCPSourceNotify
  var _header: Bool = true
  let _handler: FramedSourceHandler val
  let _runner: Runner val
  let _header_size: USize
  var _msg_count: USize = 0

  new iso create(handler: FramedSourceHandler val, runner: Runner val) => //processes_it: ProcessesIt) =>
    _handler = handler
    _runner = runner
    _header_size = _handler.header_length()

  fun ref received(conn: TCPSource ref, data: Array[U8] iso): Bool =>
    if _header then
      // TODO: we need to provide a good error handling route for crap
      try
        let payload_size: USize = _handler.payload_length(consume data)

        conn.expect(payload_size)
        _header = false
      end
      true
    else
      //processes_it.process(this, _handler.decode(consume data))
      // TODO: we need to provide a good error handling route for crap
              _msg_count = _msg_count + 1
      try
        let decoded = _handler.decode(consume data)
        if ((_msg_count % 10) == 0) then
        _runner.process(conn, decoded)
        end
      end

      conn.expect(_header_size)
      _header = true

      ifdef linux then
//        _msg_count = _msg_count + 1
        if ((_msg_count % 25) == 0) then
          false
        else
          true
        end
      else
        false
      end
    end

  fun ref accepted(conn: TCPSource ref) =>
    conn.expect(_header_size)

  // TODO: implement connect_failed
