use "files"
use "net"
use "sendence/bytes"
use "json"
use "collections"
use "sendence/hub"
use "logger"

interface MetricsOutputActor
  be apply(payload: ByteSeq)
  be dispose()

actor MonitoringHubOutput is MetricsOutputActor
  let _app_name: String
  var _conn: TCPConnection
  let _logger: Logger[String]

  be dispose() => _conn.dispose()

  new create(conn: TCPConnection,
             app_name: String, logger': Logger[String]) =>
    _conn = conn
    _app_name = app_name
    _logger = logger'

    send_connect()
    send_join()

  be send_connect() =>
    """
    Send a "connect" message to Monitoring Hub
    """
    _logger(Info) and _logger.log("    metrics-receiver: Connecting...")
    _conn.writev(Bytes.length_encode(HubJson.connect()))

  be send_join() =>
    """
    Send a "join" message to Monitoring Hub
    """
    _logger(Info) and _logger.log("    metrics-receiver: Joining [" + _app_name+ "]...")
    _conn.writev(Bytes.length_encode(HubJson.join("metrics:" + _app_name)))

  be apply(payload: ByteSeq) =>
    """
    Send a metrics messsage to Monitoring Hub
    """
    _logger(Info) and _logger.log("    metrics-receiver: Sending metrics")
    _conn.writev(Bytes.length_encode(payload))


class MonitoringHubConnectNotify is TCPConnectionNotify
  let _logger: Logger[String]

  new iso create(logger': Logger[String]) =>
    _logger = logger'

  fun ref accepted(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("    metrics-receiver: Monitoring Hub connection accepted")

  fun ref closed(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log("    metrics-receiver: Monitoring Hub connection closed")

actor MetricsFileOutput is MetricsOutputActor
  let _auth: AmbientAuth
  let _app_name: String
  let _file_path: String
  let _file: (File | None)
  let _logger: Logger[String]

  new create(auth: AmbientAuth, app_name: String, file_path: String, logger': Logger[String])
  =>
    _logger = logger'
    _auth = auth
    _app_name = app_name
    _file_path = file_path

    _file = try
      let f = File(FilePath(_auth, _file_path))
      f.set_length(0)
      _logger(Info) and _logger.log("Opened " + _file_path + " for writing")
      f
    else
      _logger(Error) and _logger.log("Could not create file at " + _file_path)
      None
    end

  be apply(payload: ByteSeq) =>
    match _file
      | let file: File =>
        file.print(payload)
        file.flush()
    end

  be dispose() =>
    match _file
    | let file: File =>
      file.flush()
      file.dispose()
    end
