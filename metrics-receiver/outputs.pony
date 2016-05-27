use "net"
use "sendence/bytes"
use "buffy/metrics"
use "json"
use "collections"


actor MonitoringHubOutput is MetricsOutputActor
  let _stdout: StdStream
  let _stderr: StdStream
  let _app_name: String
  var _conn: TCPConnection

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
    let message: Array[U8] iso = recover Array[U8] end
    let j: JsonObject = JsonObject
    j.data.update("path", "/socket/tcp")
    j.data.update("params", None)
    message.append(j.string())
    _conn.write(Bytes.length_encode(consume message))

  be send_join() =>
    """
    Send a "join" message to Monitoring Hub
    """
    _stdout.print("    metrics-receiver: Joining [" + _app_name+ "]...")
    let message: Array[U8] iso = recover Array[U8] end
    let j: JsonObject = JsonObject
    j.data.update("event", "phx_join")
    j.data.update("topic", "metrics:" + _app_name)
    j.data.update("ref", None)
    j.data.update("payload", JsonObject)
    message.append(j.string())
    _conn.write(Bytes.length_encode(consume message))

  be send(category: String, payload: Array[U8] val) =>
    """
    Send a metrics messsage to Monitoring Hub
    """
    try
      _stdout.print("    metrics-receiver: Sending metrics")
      let message: Array[U8] iso = recover Array[U8] end
      let doc: JsonDoc = JsonDoc
      doc.parse(String.from_array(payload))

      let j: JsonObject = JsonObject
      j.data.update("event", category)
      j.data.update("topic", "metrics:" + _app_name)
      j.data.update("ref", None)
      j.data.update("payload", doc.data as JsonArray)
      message.append(j.string())
      _conn.write(Bytes.length_encode(consume message))
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

