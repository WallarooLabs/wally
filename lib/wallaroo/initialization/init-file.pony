use "files"
use "net"

class InitFile
  let _filename: String
  let _file: File
  let _auth: AmbientAuth

  new create(filename: String, auth: AmbientAuth) ? =>
    _filename = filename
    _file = File(FilePath(auth, filename))
    _auth = auth

  fun ref read_into(addr: Array[String] val) =>
    let connect_auth = TCPConnectAuth(_auth)
    try
      let conn = TCPConnection(connect_auth,
        InitFileNotify, addr(0), addr(1))

      conn.write(_file.read(_file.size())) 
      _file.dispose()

      @printf[I32](("Read initialization messages from " + _filename + "\n").cstring())
      conn.dispose()
    else
      @printf[I32]("Incorrect address for init file\n".cstring())
    end


class InitFileNotify is TCPConnectionNotify
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    true
