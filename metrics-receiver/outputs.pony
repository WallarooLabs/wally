use "net"
use "sendence/bytes"

primitive EventTypes
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"


actor MonitoringHubOutput
  let _env: Env
  let _app_name: String
  var _conn: (TCPConnection | None) = None

  new create(env: Env, app_name: String, host: String, service: String) =>
    _env = env
    _app_name = app_name
    
    try
      let auth = env.root as AmbientAuth
      let notifier: TCPConnectionNotify iso =
        recover MonitoringHubConnectNotify(env, this) end
      _conn = TCPConnection(auth, consume notifier, host, service)
      send_connect()
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
        message.append("""{"path": "/socket/tcp", "params": null}""")
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
        message.append("""{"event": "phx_join", "topic": "metrics:""")
        message.append(_app_name)
        message.append("""", "ref": null, "payload": {}}""")
        c.write(Bytes.length_encode(consume message))
      else
        _env.out.print("    metrics-receiver: Failed sending join")
      end
    end

  be send(category: String, payload: String) =>
    """
    Send a metrics messsage to Monitoring Hub
    """
    if (_conn isnt None) then
      try
        _env.out.print("    metrics-receiver: Sending metrics")
        let c = _conn as TCPConnection
        let message: Array[U8] iso = recover Array[U8] end
        message.append("""{"event": """" + category + """", "topic": """)
        message.append(""""metrics:""" + _app_name + """", "ref": null,""")
        message.append(""""payload" : """" + payload + """"}""")
        c.write(Bytes.length_encode(consume message))
      else
        _env.out.print("   metrics-receiver: Failed sending metrics")
      end
    end


  be send_sinks(payload: String) =>
    send(EventTypes.sinks(), payload)

  be send_boundaries(payload: String) =>
    send(EventTypes.boundaries(), payload)

  be send_steps(payload: String) =>
    send(EventTypes.steps(), payload)


class MonitoringHubConnectNotify is TCPConnectionNotify
  let _env: Env
  let _output: MonitoringHubOutput

  new iso create(env: Env, output: MonitoringHubOutput) =>
    _env = env
    _output = output

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("    metrics-receiver: Monitoring Hub connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    // We don't actually have to do anything with this 
    None 

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon child: server closed")

