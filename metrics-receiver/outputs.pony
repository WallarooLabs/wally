use "net"
use "sendence/bytes"
use "buffy/metrics"
use "json"
use "collections"


actor MonitoringHubOutput is MetricsOutputActor
  let _env: Env
  let _app_name: String
  // TODO: Copy variable passing from giles-sender, create TCP Conn outside
  //       and pass it to actor. Same thing with files, etc.
  //       IF you fail to create the TCP stuff, can't create the acotr. Either
  //       degrade to another type of actor, or fail the process entirely.
  //       Without the None you don't have to do the "as" stuff
  var _conn: (TCPConnection | None) = None

  new create(env: Env, app_name: String, host: String, service: String) =>
    _env = env
    _app_name = app_name

    try
      let auth = env.root as AmbientAuth
      let notifier: TCPConnectionNotify iso =
        recover MonitoringHubConnectNotify(env.out, this) end
      _conn = TCPConnection(auth, consume notifier, host, service)
      send_connect()
      send_join()
    else
      _env.out.print("    metrics-receiver: Couldn't get ambient authority")
    end

  be send_connect() =>
    """
    Send a "connect" message to Monitoring Hub
    """
    if (_conn isnt None) then
      try
        _env.out.print("    metrics-receiver: Connecting...")
        let c = _conn as TCPConnection
        let message: Array[U8] iso = recover Array[U8] end
        let j: JsonObject = JsonObject
        j.data.update("path", "/socket/tcp")
        j.data.update("params", None)
        message.append(j.string())
        c.write(Bytes.length_encode(consume message))
      else
        _env.out.print("    metrics-receiver: Failed sending connect")
      end
    end

  be send_join() =>
    """
    Send a "join" message to Monitoring Hub
    """
    if (_conn isnt None) then
      try
        _env.out.print("    metrics-receiver: Joining [" + _app_name+ "]...")
        let c = _conn as TCPConnection
        let message: Array[U8] iso = recover Array[U8] end
        let j: JsonObject = JsonObject
        j.data.update("event", "phx_join")
        j.data.update("topic", "metrics:" + _app_name)
        j.data.update("ref", None)
        j.data.update("payload", JsonObject)
        message.append(j.string())
        c.write(Bytes.length_encode(consume message))
      else
        _env.out.print("    metrics-receiver: Failed sending join")
      end
    end

  be send(category: String, payload: Array[U8] val) =>
    """
    Send a metrics messsage to Monitoring Hub
    """
    if (_conn isnt None) then
      try
        _env.out.print("    metrics-receiver: Sending metrics")
        let c = _conn as TCPConnection
        let message: Array[U8] iso = recover Array[U8] end
        let doc: JsonDoc = JsonDoc
        doc.parse(String.from_array(payload))

        let j: JsonObject = JsonObject
        j.data.update("event", category)
        j.data.update("topic", "metrics:" + _app_name)
        j.data.update("ref", None)
        j.data.update("payload", doc.data as JsonArray)
        message.append(j.string())
        c.write(Bytes.length_encode(consume message))
      else
        _env.out.print("   metrics-receiver: Failed sending metrics")
      end
    end


class MonitoringHubConnectNotify is TCPConnectionNotify
  let _outstream: StdStream
  let _output: MonitoringHubOutput

  new iso create(outstream: StdStream, output: MonitoringHubOutput) =>
    _outstream = outstream
    _output = output

  fun ref accepted(conn: TCPConnection ref) =>
    _outstream.print("    metrics-receiver: Monitoring Hub connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    // We don't actually have to do anything with this
    None

  fun ref closed(conn: TCPConnection ref) =>
    _outstream.print("dagon child: server closed")

