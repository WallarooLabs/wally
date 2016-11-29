use "files"
use "net"
use "sendence/bytes"
use "wallaroo"

class InitFileReader
  let _filename: String
  let _msg_size: USize
  let _file: File
  let _auth: AmbientAuth

  new create(init_file: InitFile val, auth: AmbientAuth) ? =>
    _filename = init_file.filename
    match init_file.msg_size
    | let ms: USize =>
      _msg_size = ms
    else
      @printf[I32]("Only binary files are currently supported for initialization. You must supply a message size when specifying InitFile.\n".cstring())
      error
    end
    _auth = auth
    _file = File(FilePath(_auth, _filename))

  fun ref read_into(addr: Array[String] val) =>
    let connect_auth = TCPConnectAuth(_auth)
    try
      let conn = TCPConnection(connect_auth,
        InitFileNotify, addr(0), addr(1))

      while _file.position() < _file.size() do
        conn.write(_file.read(_msg_size))
      end

      _file.dispose()
      conn.dispose()

      @printf[I32](("Read initialization messages from " + _filename + "\n").cstring())
      // TODO: Calling this here makes reading in messages non-deterministic.
      // Disposal must be handled later and elsewhere.
      // conn.dispose()
    else
      @printf[I32]("Incorrect address for init file\n".cstring())
    end


class InitFileNotify is TCPConnectionNotify
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    true
