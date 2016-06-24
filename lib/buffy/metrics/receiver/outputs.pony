use "files"
use "net"
use "sendence/bytes"
use "buffy/metrics"
use "json"
use "collections"
use "sendence/hub"

actor MonitoringHubOutput is MetricsOutputActor
  let _stdout: StdStream
  let _stderr: StdStream
  let _app_name: String
  var _conn: TCPConnection

  be dispose() => None

  new create(stdout: StdStream, stderr: StdStream, conn: TCPConnection,
             app_name: String) =>
    _stdout = stdout
    _stderr = stderr
    _conn = conn
    _app_name = app_name

    send_connect()
    send_join()

  be send_connect() =>
    """
    Send a "connect" message to Monitoring Hub
    """
    _stdout.print("    metrics-receiver: Connecting...")
    _conn.writev(Bytes.length_encode(HubJson.connect()))

  be send_join() =>
    """
    Send a "join" message to Monitoring Hub
    """
    _stdout.print("    metrics-receiver: Joining [" + _app_name+ "]...")
    _conn.writev(Bytes.length_encode(HubJson.join("metrics:" + _app_name)))

  be apply(category: String, payload: Array[U8] val) =>
    """
    Send a metrics messsage to Monitoring Hub
    """
    try
      _stdout.print("    metrics-receiver: Sending metrics")
      let doc: JsonDoc = JsonDoc
      doc.parse(String.from_array(payload))
      let msg = HubJson.payload(category, "metrics:" + _app_name,
        doc.data as JsonArray)
      _conn.writev(Bytes.length_encode(msg))
    else
      _stderr.print("   metrics-receiver: Failed sending metrics")
    end


class MonitoringHubConnectNotify is TCPConnectionNotify
  let _stdout: StdStream
  let _stderr: StdStream

  new iso create(stdout: StdStream, stderr: StdStream) =>
    _stdout = stdout
    _stderr = stderr

  fun ref accepted(conn: TCPConnection ref) =>
    _stdout.print("    metrics-receiver: Monitoring Hub connection accepted")

  fun ref closed(conn: TCPConnection ref) =>
    _stdout.print("    metrics-receiver: Monitoring Hub connection closed")

actor MetricsFileOutput is MetricsOutputActor
  let _stdout: StdStream
  let _stderr: StdStream
  let _auth: AmbientAuth
  let _app_name: String
  let _file_path: String
  let _file: (File | None)

  new create(stdout: StdStream, stderr: StdStream, auth: AmbientAuth,
    app_name: String, file_path: String)
  =>
    _stdout = stdout
    _stderr = stderr
    _auth = auth
    _app_name = app_name
    _file_path = file_path

    _file = try
      let f = File(FilePath(_auth, _file_path))
      f.set_length(0)
      _stdout.print("Opened " + _file_path + " for writing")
      f
    else
      _stderr.print("Could not create file at " + _file_path)
      None
    end

  be apply(category: String, payload: Array[U8 val] val) =>
    match _file
      | let file: File =>
        try
          let doc: JsonDoc = JsonDoc
          doc.parse(String.from_array(payload))
          let msg = HubJson.payload(category, "metrics:" + _app_name,
            doc.data as JsonArray)
          file.print(msg)
        end
    end

  be dispose() =>
    match _file
    | let file: File => file.dispose()
    end
